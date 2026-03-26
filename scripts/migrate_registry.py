#!/usr/bin/env python3
"""Migrate tbxmanager packages from old web2py/SQLite to new JSON registry format."""

import argparse
import json
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

PLATFORM_MAP = {
    "win64": "win64",
    "pcwin64": "win64",
    "maci64": "maci64",
    "maca64": "maca64",
    "glnxa64": "glnxa64",
    "all": "all",
    # Skip 32-bit legacy platforms
    "pcwin": None,
    "glnx86": None,
    "maci": None,
}

STABLE_REPO_ID = 1


def connect_db(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def get_packages(conn):
    """Get all public packages."""
    cursor = conn.execute("SELECT * FROM package WHERE public = 'T' ORDER BY ident")
    return cursor.fetchall()


def get_versions(conn, package_id):
    """Get stable versions for a package."""
    cursor = conn.execute(
        "SELECT * FROM version WHERE package_id = ? AND repository_id = ? "
        "ORDER BY created_on DESC",
        (package_id, STABLE_REPO_ID),
    )
    return cursor.fetchall()


def get_links(conn, version_id):
    """Get download links for a version."""
    cursor = conn.execute(
        "SELECT l.*, p.ident AS platform_ident "
        "FROM link l JOIN platform p ON l.platform_id = p.id "
        "WHERE l.version_id = ?",
        (version_id,),
    )
    return cursor.fetchall()


def get_maintainers(conn, package_id):
    """Get maintainer info for a package."""
    cursor = conn.execute(
        "SELECT u.first_name, u.last_name, u.email "
        "FROM maintainer m JOIN auth_user u ON m.user_id = u.id "
        "WHERE m.package_id = ?",
        (package_id,),
    )
    return cursor.fetchall()


def check_url(url, timeout=30):
    """HEAD request to check if URL is reachable."""
    try:
        req = urllib.request.Request(url, method="HEAD")
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status == 200
    except urllib.error.URLError, urllib.error.HTTPError, OSError:
        return False


def format_date(date_str):
    """Convert web2py date to YYYY-MM-DD."""
    if not date_str:
        return None
    try:
        dt = datetime.fromisoformat(str(date_str).replace(" ", "T"))
        return dt.strftime("%Y-%m-%d")
    except ValueError, TypeError:
        return None


def migrate_package(conn, package, check_urls=False):
    """Migrate a single package to registry format."""
    warnings = []
    pkg_id = package["id"]
    ident = package["ident"]

    versions = get_versions(conn, pkg_id)
    if not versions:
        return None, [f"[WARN] {ident}: no stable versions, skipping"]

    maintainers = get_maintainers(conn, pkg_id)
    authors = []
    for m in maintainers:
        name = f"{m['first_name']} {m['last_name']}".strip()
        if m["email"]:
            authors.append(f"{name} <{m['email']}>")
        elif name:
            authors.append(name)

    if not authors and package["email"]:
        authors.append(package["email"])

    entry = {
        "name": ident,
        "description": package["description"] or package["name"] or ident,
    }

    if package["homepage"]:
        entry["homepage"] = package["homepage"]

    license_text = package["license"] if package["license"] else None
    if license_text:
        entry["license"] = license_text

    if authors:
        entry["authors"] = authors

    entry["versions"] = {}
    total_links = 0
    broken_urls = []

    for ver in versions:
        ver_ident = ver["ident"]
        links = get_links(conn, ver["id"])

        if not links:
            warnings.append(
                f"[WARN] {ident}@{ver_ident}: no download links, skipping version"
            )
            continue

        platforms = {}
        skipped_platforms = []

        for link in links:
            plat_ident = link["platform_ident"]
            mapped = PLATFORM_MAP.get(plat_ident)

            if mapped is None:
                skipped_platforms.append(plat_ident)
                continue

            url = link["url"]
            if check_urls and not check_url(url):
                broken_urls.append(f"{ident}@{ver_ident} [{mapped}]: {url}")

            platforms[mapped] = {
                "url": url,
                "sha256": None,
            }
            total_links += 1

        if skipped_platforms:
            warnings.append(
                f"[INFO] {ident}@{ver_ident}: skipped legacy platforms: {', '.join(skipped_platforms)}"
            )

        if not platforms:
            warnings.append(
                f"[WARN] {ident}@{ver_ident}: no valid platforms after mapping, skipping"
            )
            continue

        ver_entry = {
            "matlab": ">=R2014a",
            "dependencies": {},
            "platforms": platforms,
        }

        released = format_date(
            ver["created_on"] if "created_on" in ver.keys() else None
        )
        if released:
            ver_entry["released"] = released

        entry["versions"][ver_ident] = ver_entry

    if not entry["versions"]:
        return None, warnings + [
            f"[WARN] {ident}: no valid versions after migration, skipping"
        ]

    if broken_urls:
        for bu in broken_urls:
            warnings.append(f"[ERROR] Broken URL: {bu}")

    return entry, warnings


def build_index(packages_dir):
    """Combine all package.json files into index.json."""
    index = {
        "index_version": 1,
        "generated": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "packages": {},
    }

    for pkg_file in sorted(packages_dir.glob("*/package.json")):
        with open(pkg_file) as f:
            pkg = json.load(f)

        name = pkg["name"]
        versions = list(pkg.get("versions", {}).keys())

        if versions:
            # Sort versions by semver (simple numeric sort)
            def ver_key(v):
                parts = v.split(".")
                return tuple(int(p) for p in parts)

            versions_sorted = sorted(versions, key=ver_key)
            latest = versions_sorted[-1]
        else:
            latest = ""

        index_entry = dict(pkg)
        index_entry["latest"] = latest
        index["packages"][name] = index_entry

    return index


def main():
    parser = argparse.ArgumentParser(
        description="Migrate tbxmanager packages from SQLite to JSON registry format"
    )
    parser.add_argument("--db", required=True, help="Path to storage.sqlite database")
    parser.add_argument(
        "--output", required=True, help="Output directory for registry files"
    )
    parser.add_argument(
        "--check-urls", action="store_true", help="Check download URL liveness"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without writing files",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    output_dir = Path(args.output)

    if not db_path.exists():
        print(f"[ERROR] Database not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    conn = connect_db(str(db_path))

    # Check if public column uses 'T' or True
    try:
        packages = get_packages(conn)
    except sqlite3.OperationalError:
        # Try boolean format
        cursor = conn.execute("SELECT * FROM package WHERE public = 1 ORDER BY ident")
        packages = cursor.fetchall()

    print(f"[INFO] Found {len(packages)} public packages")

    all_warnings = []
    migrated = 0
    skipped = 0
    total_versions = 0
    total_links = 0

    for package in packages:
        entry, warnings = migrate_package(conn, package, check_urls=args.check_urls)
        all_warnings.extend(warnings)

        if entry is None:
            skipped += 1
            continue

        pkg_dir = output_dir / "packages" / entry["name"]
        pkg_file = pkg_dir / "package.json"

        n_versions = len(entry["versions"])
        n_links = sum(len(v["platforms"]) for v in entry["versions"].values())

        total_versions += n_versions
        total_links += n_links

        if args.dry_run:
            print(
                f"[DRY-RUN] Would write {pkg_file} ({n_versions} versions, {n_links} links)"
            )
        else:
            pkg_dir.mkdir(parents=True, exist_ok=True)
            with open(pkg_file, "w") as f:
                json.dump(entry, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print(f"[OK] {entry['name']}: {n_versions} versions, {n_links} links")

        migrated += 1

    # Build combined index
    if not args.dry_run and migrated > 0:
        packages_dir = output_dir / "packages"
        index = build_index(packages_dir)
        index_file = output_dir / "index.json"
        with open(index_file, "w") as f:
            json.dump(index, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"\n[OK] Built index.json with {len(index['packages'])} packages")

    # Summary
    print(f"\n{'=' * 50}")
    print("Migration Summary")
    print(f"{'=' * 50}")
    print(f"Packages migrated: {migrated}")
    print(f"Packages skipped:  {skipped}")
    print(f"Total versions:    {total_versions}")
    print(f"Total links:       {total_links}")

    if all_warnings:
        print(f"\nWarnings/Errors ({len(all_warnings)}):")
        for w in all_warnings:
            print(f"  {w}")

    conn.close()


if __name__ == "__main__":
    main()
