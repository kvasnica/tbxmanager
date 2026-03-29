#!/usr/bin/env python3
r"""Convert tbxmanager.json to registry package.json format.

Transforms the author-side package manifest into the registry format,
optionally merging with an existing registry entry to add a new version.

Usage:
    # Convert a new package (no existing registry entry)
    python scripts/convert_to_registry.py --input tbxmanager.json --output packages/mpt/package.json

    # Add a version to an existing registry entry
    python scripts/convert_to_registry.py --input tbxmanager.json --existing packages/mpt/package.json --output packages/mpt/package.json

    # Override SHA256 hashes and URLs (used by publish action)
    python scripts/convert_to_registry.py --input tbxmanager.json --output out.json \
        --sha256 maci64=abc123...def --sha256 win64=fed321...cba \
        --url maci64=https://...maci64.zip --url win64=https://...win64.zip

    # Set release date (defaults to today)
    python scripts/convert_to_registry.py --input tbxmanager.json --output out.json --released 2026-03-28
"""

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_-]*$")
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+(\.[0-9]+)?$")
VALID_PLATFORMS = {"win64", "maci64", "maca64", "glnxa64", "all"}


def parse_kv_arg(value):
    """Parse 'key=value' argument into (key, value) tuple."""
    if "=" not in value:
        raise argparse.ArgumentTypeError(f"Expected key=value format, got: {value}")
    key, _, val = value.partition("=")
    return key, val


def validate_input(pkg):
    """Validate the tbxmanager.json content. Returns list of error strings."""
    errors = []

    for field in ("name", "version", "description", "platforms"):
        if field not in pkg:
            errors.append(f"Missing required field: {field}")

    if errors:
        return errors

    if not NAME_PATTERN.match(pkg["name"]):
        errors.append(f"Invalid package name: {pkg['name']}")

    if not VERSION_PATTERN.match(pkg["version"]):
        errors.append(f"Invalid version: {pkg['version']}")

    platforms = pkg["platforms"]
    if not isinstance(platforms, dict) or len(platforms) == 0:
        errors.append("'platforms' must be a non-empty object")
    else:
        for plat in platforms:
            if plat not in VALID_PLATFORMS:
                errors.append(f"Invalid platform: {plat}")
            url = platforms[plat]
            if not isinstance(url, str) or not url.startswith("https://"):
                errors.append(f"Platform '{plat}' URL must be an HTTPS string")

    return errors


def convert(pkg, sha256_overrides=None, url_overrides=None, released=None):
    """Convert tbxmanager.json dict to a registry version entry.

    Args:
        pkg: Parsed tbxmanager.json content.
        sha256_overrides: Dict of platform -> sha256 hex string.
        url_overrides: Dict of platform -> URL string (overrides URLs in pkg).
        released: Release date string (YYYY-MM-DD). Defaults to today.

    Returns:
        Tuple of (top_level_fields, version_key, version_entry).
    """
    sha256_overrides = sha256_overrides or {}
    url_overrides = url_overrides or {}
    released = released or date.today().isoformat()

    # Build platform artifacts
    platforms = {}
    for plat, url in pkg["platforms"].items():
        actual_url = url_overrides.get(plat, url)
        sha256 = sha256_overrides.get(plat)
        artifact = {"url": actual_url}
        artifact["sha256"] = sha256 if sha256 else None
        platforms[plat] = artifact

    # Build version entry
    version_entry = {"platforms": platforms, "released": released}

    if "matlab" in pkg:
        version_entry["matlab"] = pkg["matlab"]

    if "dependencies" in pkg and pkg["dependencies"]:
        version_entry["dependencies"] = pkg["dependencies"]

    # Top-level fields
    top_level = {
        "name": pkg["name"],
        "description": pkg["description"],
    }
    for field in ("homepage", "license", "authors"):
        if field in pkg:
            top_level[field] = pkg[field]

    return top_level, pkg["version"], version_entry


def merge_into_existing(existing, top_level, version_key, version_entry):
    """Merge a new version into an existing registry package.json.

    Updates top-level metadata and adds the version entry.
    If the version already exists, it is overwritten with a warning.

    Returns:
        Tuple of (merged_dict, warnings).
    """
    warnings = []
    result = dict(existing)

    # Update top-level metadata from latest submission
    for field in ("description", "homepage", "license", "authors"):
        if field in top_level:
            result[field] = top_level[field]

    if "versions" not in result:
        result["versions"] = {}

    if version_key in result["versions"]:
        warnings.append(f"Overwriting existing version {version_key}")

    result["versions"][version_key] = version_entry

    return result, warnings


def build_new_entry(top_level, version_key, version_entry):
    """Build a new registry package.json from scratch."""
    result = dict(top_level)
    result["versions"] = {version_key: version_entry}
    return result


def main():  # noqa: D103
    parser = argparse.ArgumentParser(
        description="Convert tbxmanager.json to registry package.json format"
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to tbxmanager.json (author's package manifest)",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output path for registry package.json",
    )
    parser.add_argument(
        "--existing",
        help="Path to existing registry package.json (for version merging)",
    )
    parser.add_argument(
        "--sha256",
        type=parse_kv_arg,
        action="append",
        default=[],
        help="SHA256 hash override: platform=hexhash (repeatable)",
    )
    parser.add_argument(
        "--url",
        type=parse_kv_arg,
        action="append",
        default=[],
        help="URL override: platform=url (repeatable)",
    )
    parser.add_argument(
        "--released",
        help="Release date in YYYY-MM-DD format (defaults to today)",
    )
    args = parser.parse_args()

    # Read input
    input_path = Path(args.input)
    try:
        with open(input_path) as f:
            pkg = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"[ERROR] Cannot read {input_path}: {e}", file=sys.stderr)
        sys.exit(1)

    # Validate
    errors = validate_input(pkg)
    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)

    # Parse overrides
    sha256_map = dict(args.sha256)
    url_map = dict(args.url)

    # Convert
    top_level, version_key, version_entry = convert(
        pkg,
        sha256_overrides=sha256_map,
        url_overrides=url_map,
        released=args.released,
    )

    # Merge or create
    if args.existing:
        existing_path = Path(args.existing)
        try:
            with open(existing_path) as f:
                existing = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(
                f"[ERROR] Cannot read existing file {existing_path}: {e}",
                file=sys.stderr,
            )
            sys.exit(1)

        result, warnings = merge_into_existing(
            existing, top_level, version_key, version_entry
        )
        for w in warnings:
            print(f"[WARN] {w}", file=sys.stderr)
    else:
        result = build_new_entry(top_level, version_key, version_entry)

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
        f.write("\n")

    n_versions = len(result.get("versions", {}))
    print(
        f"Wrote {output_path}: {result['name']}@{version_key} ({n_versions} total versions)"
    )


if __name__ == "__main__":
    main()
