#!/usr/bin/env python3
"""Combine individual package.json files into a single index.json."""

import argparse
import json
import sys
from datetime import datetime, UTC
from pathlib import Path


def parse_version(v):
    """Parse version string to comparable tuple."""
    parts = v.split(".")
    try:
        return tuple(int(p) for p in parts)
    except ValueError:
        return (0,)


def build_index(packages_dir):
    """Walk packages/*/package.json and merge into index."""
    index = {
        "index_version": 1,
        "generated": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "packages": {},
    }

    total_versions = 0
    errors = []

    for pkg_file in sorted(packages_dir.glob("*/package.json")):
        try:
            with open(pkg_file) as f:
                pkg = json.load(f)
        except json.JSONDecodeError as e:
            errors.append(f"Invalid JSON in {pkg_file}: {e}")
            continue

        name = pkg.get("name")
        if not name:
            errors.append(f"Missing 'name' in {pkg_file}")
            continue

        description = pkg.get("description")
        if not description:
            errors.append(f"Missing 'description' in {pkg_file}")
            continue

        versions = pkg.get("versions", {})
        if not versions:
            errors.append(f"No versions in {pkg_file}")
            continue

        # Determine latest version
        version_keys = list(versions.keys())
        version_keys_sorted = sorted(version_keys, key=parse_version)
        latest = version_keys_sorted[-1]

        # Build index entry (include full version data for client use)
        entry = {
            "name": name,
            "description": description,
            "latest": latest,
            "versions": versions,
        }

        # Copy optional top-level fields
        for field in ("homepage", "license", "authors"):
            if field in pkg:
                entry[field] = pkg[field]

        index["packages"][name] = entry
        total_versions += len(versions)

    return index, total_versions, errors


def main():
    parser = argparse.ArgumentParser(
        description="Build combined index.json from individual package files"
    )
    parser.add_argument(
        "--packages-dir",
        required=True,
        help="Directory containing packages/*/package.json",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output path for index.json",
    )
    args = parser.parse_args()

    packages_dir = Path(args.packages_dir)
    output_path = Path(args.output)

    if not packages_dir.exists():
        print(f"[ERROR] Packages directory not found: {packages_dir}", file=sys.stderr)
        sys.exit(1)

    index, total_versions, errors = build_index(packages_dir)

    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
        f.write("\n")

    n_packages = len(index["packages"])
    print(f"Built index: {n_packages} packages, {total_versions} total versions")

    if errors:
        print(f"Errors: {len(errors)} (see above)")
        sys.exit(1)


if __name__ == "__main__":
    main()
