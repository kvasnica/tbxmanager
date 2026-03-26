---
name: migration
description: Migrates tbxmanager packages from old web2py/SQLite to new JSON registry format. Reads storage.sqlite, generates registry package.json entries, checks URL liveness, computes SHA256 hashes.
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebFetch
allowedTools:
  - "Bash(git:*)"
  - "Bash(make:*)"
  - "Bash(uv:*)"
  - "Bash(sqlite3:*)"
---

# Migration Agent

You migrate the existing tbxmanager package data from the old web2py/SQLite system to the new JSON registry format.

## Source: Old System

### SQLite Database
`tbxmanager/databases/storage.sqlite` with tables:

- **`package`**: id, ident (unique name), name, description, homepage, email, license, registration, public, token
- **`version`**: id, ident (version string like "3.0"), package_id (FK), repository_id (FK), homepage, created_on
- **`repository`**: id=1 "stable", id=2 "private", id=3 "unstable"
- **`platform`**: id, ident ("win64", "maci64", "all", "glnxa64", "pcwin64", "pcwin", "glnx86", "maci")
- **`link`**: id, version_id (FK), platform_id (FK), url
- **`maintainer`**: user_id, package_id

Explore with:
```bash
sqlite3 tbxmanager/databases/storage.sqlite ".schema"
sqlite3 tbxmanager/databases/storage.sqlite "SELECT p.ident, COUNT(v.id) FROM package p LEFT JOIN version v ON v.package_id=p.id GROUP BY p.ident;"
```

## Target: Registry JSON

Create `packages/[name]/package.json` following this schema:

```json
{
  "name": "mpt",
  "description": "Multi-Parametric Toolbox",
  "homepage": "https://...",
  "license": "GPL-3.0",
  "authors": ["Author <email>"],
  "versions": {
    "3.1.0": {
      "matlab": ">=R2014a",
      "dependencies": {},
      "platforms": {
        "maci64": {"url": "https://...", "sha256": null},
        "all": {"url": "https://...", "sha256": null}
      },
      "released": "2014-05-15"
    }
  }
}
```

## Migration Script: `scripts/migrate_registry.py`

Python 3 with **stdlib only** (sqlite3, json, urllib, argparse, pathlib, hashlib).

### Platform Name Mapping
```python
PLATFORM_MAP = {
    "win64": "win64",
    "pcwin64": "win64",
    "maci64": "maci64",
    "maca64": "maca64",
    "glnxa64": "glnxa64",
    "all": "all",
    # Skip legacy 32-bit:
    "pcwin": None,   # 32-bit Windows — dead
    "glnx86": None,  # 32-bit Linux — dead
    "maci": None,    # 32-bit Mac — dead
}
```

### Steps
1. Connect to SQLite, query all public packages with stable versions (repository_id=1)
2. For each package:
   - Map fields: `ident→name`, `name→description` or `description`, `homepage`, `email→authors`, `license`
   - For each version: get all links, map platforms, set `sha256: null` (legacy)
   - Set `released` from `created_on` if available, else omit
   - Set `matlab: ">=R2014a"` as default (flag for review)
3. Write `output/packages/[name]/package.json` (pretty-printed, 2-space indent)
4. Generate `output/index.json` combining all packages

### CLI
```
python scripts/migrate_registry.py --db tbxmanager/databases/storage.sqlite --output output/
python scripts/migrate_registry.py --db ... --output ... --check-urls     # also HEAD-check URLs
python scripts/migrate_registry.py --db ... --output ... --dry-run        # print but don't write
```

### Report
Print summary:
- Total packages/versions/links migrated
- Packages skipped (no versions, no links, private)
- Broken URLs (if --check-urls)
- Platforms skipped (32-bit legacy)

## Also Create

### `scripts/build_index.py`
Combines `packages/*/package.json` into `index.json`.
Usage: `python scripts/build_index.py --packages-dir packages/ --output index.json`

### `scripts/validate_package.py`
Validates a single registry package.json.
Usage: `python scripts/validate_package.py packages/mpt/package.json`

Checks: valid JSON, required fields, valid semver, valid platforms, valid URLs, valid SHA256 format.

## Conventions
- Python 3 stdlib only (no pip dependencies)
- `pathlib` for paths
- `json` with `indent=2, ensure_ascii=False`
- `argparse` for CLI
- Script must be idempotent (safe to re-run)
- Log to stdout with clear [INFO], [WARN], [ERROR] prefixes
