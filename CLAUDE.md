# tbxmanager — MATLAB Package Manager

## Project Overview

tbxmanager is a SOTA MATLAB package manager inspired by `uv` (Python). It consists of:

- **`tbxmanager.m`** — Single-file MATLAB client (all code in one file as local functions)
- **GitHub Pages site** (`docs/`) — Landing page, docs, package browser at tbxmanager.com
- **CI/CD** (`.github/workflows/`) — Tests, site deployment, releases
- **Registry** (separate repo: `MarekWadinger/tbxmanager-registry`) — Community package index

## MATLAB Conventions

### Target: R2022a+

- Use `jsondecode`/`jsonencode` for JSON (not XML)
- Use `webread`/`websave` for HTTP (not `urlread`/`urlwrite`)
- Use `arguments` blocks for input validation
- Use `dictionary` type where appropriate
- Use string arrays (`"string"`) not char arrays (`'string'`) for new code
- No Java dependency except for `java.security.MessageDigest` (SHA256)

### Single-File Constraint

All MATLAB code lives in `tbxmanager.m` as local functions. This enables the one-line install:

```matlab
websave('tbxmanager.m','https://tbxmanager.com/tbxmanager.m'); tbxmanager; savepath
```

### Naming Conventions

- `tbx_` prefix — Internal helper functions (e.g., `tbx_setup`, `tbx_fetchJson`)
- `main_` prefix — Command handler functions (e.g., `main_install`, `main_update`)
- Package names — lowercase, alphanumeric, hyphens, underscores: `^[a-z][a-z0-9_-]*$`

### File Organization in tbxmanager.m

Sections in order:

1. Main entry point / command dispatcher
2. Setup & configuration
3. Platform detection
4. JSON/HTTP utilities
5. SHA256 hashing
6. Version parsing & constraints
7. Dependency resolver
8. Index & source management
9. Package storage & installation
10. Path management (enable/disable)
11. Lockfile (lock/sync)
12. Command implementations (main\_\*)
13. Output formatting
14. Migration (old → new format)

## Storage Layout

```text
~/.tbxmanager/
├── packages/[name]/[version]/   # Installed package contents
├── cache/                        # Download cache ([name]-[version]-[platform].zip)
├── state/
│   ├── enabled.json              # Currently enabled packages
│   └── sources.json              # Package index sources
└── config.json                   # User configuration
```

## Data Formats

- Package metadata: `tbxmanager.json` (in package author repos)
- Registry entries: `packages/[name]/package.json` (in tbxmanager-registry)
- Combined index: `index.json` (served via GitHub Pages)
- Lockfile: `tbxmanager.lock` (in user projects)
- All use JSON format with schemas in `tbxmanager-registry/schema/`

## Version Constraints

- `>=1.0`, `<2.0`, `>=1.0,<2.0` (range with comma=AND)
- `==1.2.3` (exact), `~=1.2` (compatible release >=1.2.0,<2.0.0)
- MATLAB: `>=R2022a` (mapped internally to comparable numbers)

## Platforms

`win64`, `maci64`, `maca64`, `glnxa64`, `all` (pure MATLAB, no MEX)

## Testing

- Framework: `matlab.unittest.TestCase` (R2022a+)
- Test files in `tests/` directory
- Mock data in `tests/fixtures/`
- CI: GitHub Actions with `matlab-actions/setup-matlab@v2`

## CI/CD Workflows (`.github/workflows/`)

### `test.yml` — Lint + MATLAB Tests

- **Triggers:** push to `dev`/`master`, PRs to `dev`
- **lint job:** ruff check, JSON schema metavalidation, fixture validation (uv cached)
- **matlab job:** 2 releases × 3 OSes matrix with MATLAB setup caching
- Reusable: called by `release.yml` via `uses: ./.github/workflows/test.yml`

### `deploy-site.yml` — Documentation

- **Triggers:** push to `master`, manual dispatch
- Builds mkdocs-material with uv (cached), deploys to GitHub Pages
- Copies `tbxmanager.m` into site root for direct download

### `release.yml` — Version Bump + GitHub Release

- **Triggers:** automatic on push to `master`
- **Guard:** skips if commit message starts with `bump:` (prevents infinite loop)
- Uses `commitizen-tools/commitizen-action@master` with `PERSONAL_ACCESS_TOKEN`
- Generates changelog increment (`body.md`) and creates GitHub Release with `tbxmanager.m`
- **Requires:** `PERSONAL_ACCESS_TOKEN` repo secret (PAT with repo scope — `GITHUB_TOKEN` won't trigger downstream workflows)

### Flow

```text
PR to dev  ──→  test.yml (lint + MATLAB matrix)
                    │
merge to master ──→ deploy-site.yml (docs)
                ──→ release.yml (auto bump + changelog + GitHub Release)
```

### Caching

- **uv:** `astral-sh/setup-uv@v6` with `enable-cache: true` (test, deploy-site)
- **MATLAB:** `matlab-actions/setup-matlab@v2` with `cache: true`

## Git Workflow

- Feature branches off `dev`
- PRs to `dev`
- Releases: merge `dev` → `master` triggers automatic version bump
- Main branch: `master`

### Verification Policy (MANDATORY)

**All code changes MUST be verified before committing.** Never commit code that hasn't been executed and confirmed working.

- **MATLAB changes** (`tbxmanager.m`, `tests/*.m`): run `make test-matlab-verbose` or `make test-matlab-single CLASS=TestName`
- **Python changes** (`scripts/`): run `make test`
- **Schema changes** (`scripts/schemas/`): run `make validate`
- MATLAB R2025b is installed locally at `/Applications/MATLAB_R2025b.app/bin/matlab`
- Tests must be **self-contained**: create all mock data at runtime (zip, tar.gz, JSON), never depend on static fixture files
- If tests fail, fix the code before committing — do not commit broken code

### Commit Policy (MANDATORY)

**Commit after every completed unit of work.** Do not batch up changes across multiple tasks.

1. After finishing a logical piece of work (new file, feature, fix, refactor), immediately stage and commit.
2. **Verify changes pass tests before committing** (see Verification Policy above).
3. Use conventional commit format: `<type>(<scope>): <description>` (enforced by commitizen pre-commit hook).
4. Write descriptive commit messages — they are the source for `cz changelog`. Do NOT manually edit CHANGELOG.md.
5. Always include `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>` trailer.
6. Always ask the user for approval before running `git commit`.
7. Never use `git add -A` or `git add .` — stage specific files by name.
8. Valid types: `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, `perf`.
9. Valid scopes: `client`, `registry`, `schema`, `site`, `migration`, `agents`, `tests`.
10. Releases: use `cz bump` (bumps version, generates CHANGELOG.md, creates git tag).
