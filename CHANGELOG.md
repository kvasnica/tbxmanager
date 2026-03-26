## v2.0.0 (2026-03-26)

### Feat

- release tbxmanager 2.0 (uv-style package manager for MATLAB)
- add pull request template for consistent PR submissions
- **client**: add internal__ test API and TBXMANAGER_HOME env var
- **client**: rewrite tbxmanager.m for R2022a+ with JSON registry
- **site**: add mkdocs-material documentation site
- **schema**: add JSON schemas, registry scripts, and test fixtures

### Fix

- add emoji support to markdown configuration
- add version provider to cz
- **client**: guard all input() calls for non-interactive/batch mode
- **client**: use fprintf instead of fwrite for JSON file writing
- **client**: remove UTF-8 encoding param from fopen in tbx_writeJson
- **client**: rewrite tbx_sha256 to use MATLAB fread instead of Java FileInputStream
- **tests**: fix teardown order for Windows directory lock
- **tests**: write raw JSON for sources and use uint8 in SHA256 test
- **client**: handle jsondecode cell array edge cases in getSources
- **client**: handle file:// URLs and jsondecode version key mangling
- **tests**: fix internal__ API to use return values instead of ans

### Refactor

- cleanup remote tests
- **tests**: remove legacy t_NNN test files
- **agents**: delegate changelog and versioning to commitizen

### Perf

- **client**: cache tbx_platformArch to avoid repeated system() calls
