# tbxmanager — MATLAB Package Manager

## Project Overview

tbxmanager is a SOTA MATLAB package manager inspired by `uv` (Python). It consists of:

- **`tbxmanager.m`** — Single-file MATLAB client (all code in one file as local functions)
- **GitHub Pages site** (`docs/`) — Landing page, docs, package browser at tbxmanager.com
- **CI/CD** (`.github/workflows/`) — Tests, site deployment, releases
- **Registry** (separate repo: `kvasnica/tbxmanager-registry`) — Community package index

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

## Git Workflow

- Feature branches off `dev`
- PRs to `dev`
- Releases: merge `dev` → `master`, tag `v*`
- Main branch: `master`

### Commit Policy (MANDATORY)

**Commit after every completed unit of work.** Do not batch up changes across multiple tasks.

1. After finishing a logical piece of work (new file, feature, fix, refactor), immediately stage and commit.
2. Use conventional commit format: `<type>(<scope>): <description>` (enforced by commitizen pre-commit hook).
3. Write descriptive commit messages — they are the source for `cz changelog`. Do NOT manually edit CHANGELOG.md.
4. Always include `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>` trailer.
5. Always ask the user for approval before running `git commit`.
6. Never use `git add -A` or `git add .` — stage specific files by name.
7. Valid types: `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, `perf`.
8. Valid scopes: `client`, `registry`, `schema`, `site`, `migration`, `agents`, `tests`.
9. Releases: use `cz bump` (bumps version, generates CHANGELOG.md, creates git tag).
