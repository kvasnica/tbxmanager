# Contributing

## How the Registry Works

The tbxmanager registry is a Git repository at [kvasnica/tbxmanager-registry](https://github.com/kvasnica/tbxmanager-registry). Each package has a JSON file at `packages/[name]/package.json` containing metadata and download URLs for all versions.

When a PR is merged:

1. CI rebuilds `index.json` — a combined index of all packages
2. The index is deployed to GitHub Pages
3. The MATLAB client fetches this index to discover packages

## Submitting a New Package

1. **Fork** the [tbxmanager-registry](https://github.com/kvasnica/tbxmanager-registry) repo
2. **Create** `packages/your-package/package.json` with the required format
3. **Open a PR** — CI validates your submission automatically
4. **Fix any issues** flagged by CI
5. **Maintainers review and merge**

### What CI Checks

- Valid JSON syntax
- Required fields present (name, description, versions)
- Package name matches directory name
- Valid version strings (semver)
- Valid platform names (win64, maci64, maca64, glnxa64, all)
- HTTPS download URLs
- SHA256 hash format (64-char hex)
- URL reachability (HEAD request)

## Package JSON Format

See [Creating Packages](creating-packages.md) for the full format specification.

## Updating an Existing Package

1. Edit `packages/your-package/package.json`
2. Add a new version entry to the `versions` object
3. Open a PR

## Reporting Issues

- **Broken download links**: Open an issue on the registry repo
- **Package bugs**: Contact the package author (see homepage/authors)
- **tbxmanager client bugs**: Open an issue on [kvasnica/tbxmanager](https://github.com/kvasnica/tbxmanager)

## Contributing to tbxmanager Itself

1. Fork [kvasnica/tbxmanager](https://github.com/kvasnica/tbxmanager)
2. Create a feature branch from `dev`
3. Make changes to `tbxmanager.m` and add tests
4. Open a PR to `dev`

### Development Setup

```matlab
% Clone and work on tbxmanager.m
% Run tests:
cd tests
results = runtests;
```

### Code Conventions

- All code in `tbxmanager.m` as local functions
- `tbx_` prefix for internal helpers, `main_` prefix for commands
- MATLAB R2022a+ features only
- Tests using `matlab.unittest.TestCase`
