#!/usr/bin/env python3
"""Validate a registry package.json file."""

import argparse
import json
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_-]*$")
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+(\.[0-9]+)?$")
MATLAB_PATTERN = re.compile(r"^(>=|==)R20[0-9]{2}[ab]$")
SHA256_PATTERN = re.compile(r"^[a-f0-9]{64}$")
VALID_PLATFORMS = {"win64", "maci64", "maca64", "glnxa64", "all"}


def validate(filepath, check_urls=False):
    """Validate a package.json file. Returns (ok, messages)."""
    path = Path(filepath)
    messages = []
    ok = True

    def fail(msg):
        nonlocal ok
        ok = False
        messages.append(f"FAIL: {msg}")

    def warn(msg):
        messages.append(f"WARN: {msg}")

    def info(msg):
        messages.append(f"INFO: {msg}")

    # 1. Valid JSON
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        fail(f"Invalid JSON: {e}")
        return False, messages
    except FileNotFoundError:
        fail(f"File not found: {path}")
        return False, messages

    # 2. Required fields
    for field in ("name", "description", "versions"):
        if field not in data:
            fail(f"Missing required field: {field}")

    if not ok:
        return False, messages

    name = data["name"]
    description = data["description"]
    versions = data["versions"]

    # 3. Name matches directory
    dir_name = path.parent.name
    if name != dir_name:
        fail(f"Package name '{name}' does not match directory '{dir_name}'")

    # 4. Name pattern
    if not NAME_PATTERN.match(name):
        fail(f"Invalid package name '{name}' (must match {NAME_PATTERN.pattern})")

    # 5. Description length
    if len(description) > 200:
        warn(f"Description exceeds 200 characters ({len(description)})")

    # 6. Versions
    if not isinstance(versions, dict) or len(versions) == 0:
        fail("'versions' must be a non-empty object")
        return ok, messages

    for ver_str, ver_data in versions.items():
        prefix = f"{name}@{ver_str}"

        # Version string format
        if not VERSION_PATTERN.match(ver_str):
            fail(
                f"{prefix}: Invalid version string (must be MAJOR.MINOR or MAJOR.MINOR.PATCH)"
            )
            continue

        if not isinstance(ver_data, dict):
            fail(f"{prefix}: Version entry must be an object")
            continue

        # MATLAB constraint
        matlab = ver_data.get("matlab")
        if matlab and not MATLAB_PATTERN.match(matlab):
            fail(
                f"{prefix}: Invalid MATLAB constraint '{matlab}' (expected >=R20XXa/b)"
            )

        # Dependencies
        deps = ver_data.get("dependencies", {})
        if isinstance(deps, dict):
            for dep_name in deps:
                if not NAME_PATTERN.match(dep_name):
                    fail(f"{prefix}: Invalid dependency name '{dep_name}'")

        # Platforms
        platforms = ver_data.get("platforms", {})
        if not isinstance(platforms, dict) or len(platforms) == 0:
            fail(f"{prefix}: Must have at least one platform")
            continue

        for plat_name, plat_data in platforms.items():
            plat_prefix = f"{prefix} [{plat_name}]"

            if plat_name not in VALID_PLATFORMS:
                fail(
                    f"{plat_prefix}: Invalid platform (valid: {', '.join(sorted(VALID_PLATFORMS))})"
                )
                continue

            if not isinstance(plat_data, dict):
                fail(
                    f"{plat_prefix}: Platform entry must be an object with 'url' and 'sha256'"
                )
                continue

            url = plat_data.get("url")
            if not url:
                fail(f"{plat_prefix}: Missing 'url'")
            elif not url.startswith("https://"):
                fail(f"{plat_prefix}: URL must use HTTPS: {url}")

            sha256 = plat_data.get("sha256")
            if sha256 is not None and not SHA256_PATTERN.match(str(sha256)):
                fail(
                    f"{plat_prefix}: Invalid SHA256 (must be 64-char lowercase hex or null)"
                )

            # Optional URL check
            if check_urls and url and url.startswith("https://"):
                try:
                    req = urllib.request.Request(url, method="HEAD")
                    resp = urllib.request.urlopen(req, timeout=30)
                    if resp.status == 200:
                        info(f"{plat_prefix}: URL reachable")
                    else:
                        warn(f"{plat_prefix}: URL returned status {resp.status}")
                except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
                    fail(f"{plat_prefix}: URL unreachable: {e}")

        # Released date
        released = ver_data.get("released")
        if released and not re.match(r"^\d{4}-\d{2}-\d{2}$", released):
            fail(f"{prefix}: Invalid released date format (expected YYYY-MM-DD)")

    return ok, messages


def main():
    parser = argparse.ArgumentParser(description="Validate a registry package.json")
    parser.add_argument("file", help="Path to package.json")
    parser.add_argument("--check-urls", action="store_true", help="Check URL liveness")
    args = parser.parse_args()

    ok, messages = validate(args.file, check_urls=args.check_urls)

    for msg in messages:
        print(msg)

    if ok:
        print(f"\nPASS: {args.file}")
    else:
        print(f"\nFAIL: {args.file}")
        sys.exit(1)


if __name__ == "__main__":
    main()
