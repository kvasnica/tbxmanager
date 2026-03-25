---
name: github-pages
description: Builds tbxmanager.com as a Jekyll site on GitHub Pages — landing page, searchable package browser, documentation (getting started, creating packages, commands, contributing).
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

You build `tbxmanager.com` — a static site hosted on GitHub Pages from the `docs/` directory.

## Technology

- **Jekyll** (GitHub Pages native support)
- **Vanilla JS** for package browser (no frameworks)
- **Responsive CSS** — optimize for desktop (MATLAB engineers)
- **Markdown** for documentation pages

## Site Structure

```
docs/
├── _config.yml              # Jekyll config
├── _layouts/
│   └── default.html         # Base layout with nav + footer
├── _data/
│   └── packages.json        # Package data for browser (built by CI from registry)
├── assets/
│   ├── css/style.css        # Main stylesheet
│   └── js/packages.js       # Package browser logic
├── index.md                 # Landing page
├── getting-started.md       # Installation + first steps
├── creating-packages.md     # How to author packages
├── commands.md              # Full command reference
├── contributing.md          # Registry contribution guide
├── packages/
│   └── index.html           # Package browser page
├── CNAME                    # tbxmanager.com
└── tbxmanager.m             # Copied by CI for direct download
```

## Pages

### Landing Page (`index.md`)
- Hero: "The MATLAB Package Manager" with install snippet
- Feature cards: dependency resolution, lockfiles, SHA256 verification, community registry, cross-platform
- Quick start example
- CTAs: Get Started, Browse Packages

### Getting Started (`getting-started.md`)
1. Prerequisites (MATLAB R2022a+)
2. Installation (3-line command)
3. Configure `startup.m` with `tbxmanager restorepath`
4. Install first package
5. Project dependencies with `tbxmanager.json` + `tbxmanager lock` + `tbxmanager sync`

### Creating Packages (`creating-packages.md`)
1. `tbxmanager.json` format (full example)
2. Package structure
3. Platform-specific archives (MEX files)
4. Hosting on GitHub Releases
5. Submitting to registry (PR workflow)
6. Versioning (semver)

### Command Reference (`commands.md`)
Document every command: syntax, description, examples.

### Contributing (`contributing.md`)
Registry PR process, JSON format, CI validation, updating packages.

### Package Browser (`packages/index.html`)
- Fetches data from `_data/packages.json`
- Search input filters by name + description (debounced)
- Cards show: name, description, latest version, license, install command
- Pure vanilla JS, works without build tools

## Design System

```css
:root {
    --primary: #0076A8;       /* MATLAB blue */
    --primary-dark: #005580;
    --accent: #E16B2F;        /* warm accent */
    --bg: #FFFFFF;
    --bg-alt: #F5F7FA;
    --text: #1A1A2E;
    --text-muted: #6B7280;
    --border: #E5E7EB;
    --code-bg: #F3F4F6;
}
```

- System font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- Monospace: `"JetBrains Mono", "Fira Code", "SF Mono", Consolas, monospace`
- Max content width: 1200px
- Package grid: CSS Grid, 1-3 columns responsive

## CI Integration

The `deploy-site.yml` workflow:
1. Fetches `index.json` from tbxmanager-registry GitHub Pages
2. Runs `scripts/build_packages_data.py` to convert to `_data/packages.json`
3. Copies `tbxmanager.m` into `docs/` for direct download
4. Builds Jekyll → deploys to GitHub Pages

## Conventions

- Valid HTML, semantic (`<main>`, `<nav>`, `<article>`)
- CSS custom properties for theming
- No JS frameworks — vanilla modern APIs (fetch, template literals)
- Progressive enhancement — page works without JS
- CNAME file for custom domain
- `<meta>` tags for SEO
