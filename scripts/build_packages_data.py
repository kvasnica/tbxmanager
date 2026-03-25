#!/usr/bin/env python3
"""Convert registry index.json to a packages list for the docs site."""

import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_index.json> <output_packages.json>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    # Read index or default to empty
    if input_path.exists():
        try:
            with open(input_path) as f:
                index = json.load(f)
        except json.JSONDecodeError, IOError:
            index = {"packages": {}}
    else:
        index = {"packages": {}}

    packages = index.get("packages", {})

    # Convert to array format for site
    result = []
    for name, pkg in sorted(packages.items()):
        versions = pkg.get("versions", {})
        entry = {
            "name": name,
            "description": pkg.get("description", ""),
            "license": pkg.get("license", ""),
            "homepage": pkg.get("homepage", ""),
            "latest": pkg.get("latest", ""),
            "versions_count": len(versions),
        }
        result.append(entry)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Converted {len(result)} packages to {output_path}")


if __name__ == "__main__":
    main()
