---
name: github-pages
description: Builds tbxmanager.com using MkDocs Material on GitHub Pages — landing page, documentation (getting started, creating packages, commands, contributing).
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebSearch
  - WebFetch
---

# GitHub Pages Agent

You build `tbxmanager.com` — a static site hosted on GitHub Pages using MkDocs with Material theme.

## Technology

- **MkDocs** with **Material** theme (managed via `uv`)
- **Vanilla JS** for any interactive components (no frameworks)
- **Markdown** for all content pages
- Build: `uv run mkdocs build --strict`
- Serve locally: `uv run mkdocs serve`

## Configuration

Site config is in `mkdocs.yml` at the repo root (not in `docs/`).

## Site Structure

```
mkdocs.yml                       # MkDocs config (repo root)
docs/
├── index.md                     # Landing page
├── getting-started.md           # Installation + first steps
├── commands.md                  # Full command reference
├── creating-packages.md         # How to author packages
└── contributing.md              # Registry contribution guide
```

## Pages

### Landing Page (`index.md`)
- Hero: "tbxmanager" with install snippet
- Feature cards using Material grid cards
- Quick start example
- CTAs: Get Started, Browse Packages

### Getting Started (`getting-started.md`)
1. Prerequisites (MATLAB R2022a+)
2. Installation (3-line command)
3. Configure `startup.m` with `tbxmanager restorepath`
4. Install first package
5. Project dependencies with `tbxmanager.json` + `tbxmanager lock` + `tbxmanager sync`

### Command Reference (`commands.md`)
Document every command: syntax, description, examples.

### Creating Packages (`creating-packages.md`)
1. `tbxmanager.json` format (full example)
2. Package structure, platform archives
3. Hosting on GitHub Releases
4. Submitting to registry (PR workflow)

### Contributing (`contributing.md`)
Registry PR process, JSON format, CI validation, updating packages.

## CI Integration

The `deploy-site.yml` workflow:
1. Uses `astral-sh/setup-uv@v6`
2. Copies `tbxmanager.m` into `docs/` for direct download
3. Runs `uv run mkdocs build --strict`
4. Deploys `site/` to GitHub Pages

## Conventions

- Use Material theme features: grid cards, admonitions, code copy, tabs
- Markdown only — no raw HTML unless Material requires it
- Links between docs use relative `.md` paths (e.g., `[link](commands.md)`)
- Test builds with `uv run mkdocs build --strict` before committing
- CNAME for custom domain configured in GitHub repo settings (not a file)
