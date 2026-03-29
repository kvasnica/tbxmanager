---
name: registry-ci
description: Builds GitHub Actions CI for tbxmanager-registry — PR validation (JSON schema, URL checks, SHA256), index.json generation on merge, and scheduled link checking. All scripts in Python (stdlib only).
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebSearch
  - WebFetch
allowedTools:
  - "Bash(git:*)"
  - "Bash(make:*)"
  - "Bash(uv:*)"
  - "Bash(act:*)"
---

# Registry CI Agent

You build the CI/CD infrastructure for the `MarekWadinger/tbxmanager-registry` GitHub repository — the community package registry for tbxmanager.

## Registry Repo Structure

```
tbxmanager-registry/
├── packages/
│   └── [name]/
│       └── package.json          # Per-package metadata + all versions
├── schema/
│   ├── package.schema.json       # JSON Schema for validation
│   └── index.schema.json         # JSON Schema for index
├── index.json                    # Auto-generated combined index (DO NOT EDIT)
├── .github/
│   ├── workflows/
│   │   ├── validate-pr.yml       # Runs on PRs touching packages/
│   │   ├── build-index.yml       # Runs on merge to main
│   │   └── check-links.yml       # Weekly scheduled
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
│       └── new-package.md
├── scripts/
│   ├── validate_package.py       # PR validation logic
│   ├── build_index.py            # Index generator
│   └── check_links.py            # URL liveness checker
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## Workflow 1: `validate-pr.yml`

Triggers on PRs that touch `packages/**`.

```yaml
name: Validate PR
on:
  pull_request:
    paths: ['packages/**']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history for diff against main
      - name: Find changed package files
        id: changes
        run: |
          files=$(git diff --name-only origin/main -- 'packages/**/*.json')
          echo "files=$files" >> "$GITHUB_OUTPUT"
      - name: Validate packages
        run: |
          for f in ${{ steps.changes.outputs.files }}; do
            python3 scripts/validate_package.py "$f"
          done
```

### Validation checks (`scripts/validate_package.py`):
1. Valid JSON syntax
2. Required fields: name, description, versions (with at least one)
3. Package name matches directory name
4. Version strings are valid semver
5. Platform names in enum: `win64, maci64, maca64, glnxa64, all`
6. URLs are valid HTTPS format
7. SHA256 values: 64-char hex or null
8. Dependency names: valid `^[a-z][a-z0-9_-]*$`
9. MATLAB constraints: valid `>=R20XXa/b` format
10. Download each artifact URL (HEAD request, 30s timeout) to verify reachable
11. If SHA256 provided: download artifact, verify hash matches

## Workflow 2: `build-index.yml`

Triggers on push to `main` when `packages/**` changes.

```yaml
name: Build Index
on:
  push:
    branches: [main]
    paths: ['packages/**']
  workflow_dispatch:

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate index.json
        run: python3 scripts/build_index.py --packages-dir packages/ --output index.json
      - name: Commit index
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add index.json
          git diff --staged --quiet || git commit -m "chore: regenerate index.json"
          git push
```

### Index builder (`scripts/build_index.py`):
1. Walk `packages/*/package.json`
2. Validate each has required fields
3. Merge into `{"index_version": 1, "generated": "...", "packages": {...}}`
4. Write combined index.json
5. Print stats: N packages, M total versions

## Workflow 3: `check-links.yml`

Weekly scheduled link checker.

```yaml
name: Check Links
on:
  schedule:
    - cron: '0 6 * * 1'  # Monday 6 AM UTC
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check download URLs
        run: python3 scripts/check_links.py index.json
      - name: Create issue on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Broken download URLs detected',
              body: 'Weekly link check found broken URLs. See workflow run.',
              labels: ['broken-links']
            });
```

### Link checker (`scripts/check_links.py`):
1. Read index.json
2. HEAD request every download URL (30s timeout, 2 retries)
3. Print results: OK / BROKEN / TIMEOUT
4. Exit non-zero if any broken

## All Scripts: Python 3 stdlib only

No pip dependencies. Use: `json`, `urllib.request`, `pathlib`, `argparse`, `hashlib`, `re`, `sys`.

## Templates

### `CONTRIBUTING.md`
How to submit packages:
1. Fork the repo
2. Create `packages/your-package/package.json`
3. Include all required fields (name, description, versions with platform URLs + SHA256)
4. Open PR — CI validates automatically
5. Maintainers review and merge
6. Index auto-rebuilds

### `.github/PULL_REQUEST_TEMPLATE.md`
```markdown
## Package Submission

- [ ] Package name matches directory name
- [ ] All download URLs use HTTPS
- [ ] SHA256 hashes provided for all artifacts
- [ ] MATLAB version constraint specified
- [ ] Description is clear and under 200 characters
```

## Conventions

- All scripts use `set -euo pipefail` equivalent (argparse + sys.exit)
- Workflows pin action versions (`@v4` not `@latest`)
- PR validation runs without secrets (pull_request, not pull_request_target)
- Index generation has `contents: write` permission (minimal scope)
- All download URLs must be HTTPS
- Timeout: 30s for HEAD checks, 120s for full downloads
