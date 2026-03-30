# tbxmanager

[![Test](https://github.com/MarekWadinger/tbxmanager/actions/workflows/test.yml/badge.svg)](https://github.com/MarekWadinger/tbxmanager/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/MarekWadinger/tbxmanager/graph/badge.svg?token=TmB6OzWFfo)](https://codecov.io/gh/MarekWadinger/tbxmanager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![MATLAB R2022a+](https://img.shields.io/badge/MATLAB-R2022a+-orange.svg)](https://mathworks.com/products/matlab.html)

A modern package manager for MATLAB with dependency resolution, lockfiles, SHA256 integrity verification, and a community package registry.

## Installation

```matlab
websave('tbxmanager.m', 'https://marekwadinger.github.io/tbxmanager/tbxmanager.m'); tbxmanager; savepath
tbxmanager
savepath
```

Add to your `startup.m` for automatic path restoration:

```matlab
tbxmanager restorepath
```

## Usage

```matlab
tbxmanager install mpt          % Install a package (resolves dependencies)
tbxmanager search optimization  % Search available packages
tbxmanager list                 % Show installed packages
tbxmanager update               % Update all packages
tbxmanager info mpt             % Package details
```

## Features

- **One-line install** — single MATLAB file, no compilation needed
- **Dependency resolution** — automatic transitive dependency handling with version constraints
- **Lockfiles** — `tbxmanager lock` + `tbxmanager sync` for reproducible environments
- **SHA256 verification** — every download verified for integrity
- **Cross-platform** — Windows, macOS (Intel & Apple Silicon), Linux
- **Community registry** — [submit packages](https://github.com/MarekWadinger/tbxmanager-registry/issues/new?template=submit-package.yml) by filling in a form

## Commands

| Command                  | Description                                 |
| ------------------------ | ------------------------------------------- |
| `install pkg1 pkg2`      | Install packages with dependency resolution |
| `uninstall pkg1`         | Remove packages                             |
| `update [pkg]`           | Update packages (all if none specified)     |
| `list`                   | Show installed packages                     |
| `search query`           | Search available packages                   |
| `info pkg`               | Show package details                        |
| `lock`                   | Generate lockfile from `tbxmanager.json`    |
| `sync`                   | Install from lockfile                       |
| `init`                   | Create `tbxmanager.json` template           |
| `selfupdate`             | Update tbxmanager itself                    |
| `source add/remove/list` | Manage package sources                      |
| `enable/disable pkg`     | Manage MATLAB path                          |
| `restorepath`            | Restore paths (for startup.m)               |
| `require pkg1 pkg2`      | Assert packages available                   |
| `cache clean/list`       | Manage download cache                       |

## Publish Your Package

1. Add `tbxmanager.json` to your repo (or run `tbxmanager init`)
1. Create a GitHub Release with a zip archive of your package
1. [Submit via the registry issue form](https://github.com/MarekWadinger/tbxmanager-registry/issues/new?template=submit-package.yml) — a bot handles SHA256, validation, and the PR

See the [Quick Start for Authors](https://tbxmanager.com/quick-start-authors) for the full guide.

## Documentation

Full documentation at [tbxmanager.com](https://tbxmanager.com):

- [Getting Started](https://tbxmanager.com/getting-started)
- [Quick Start for Authors](https://tbxmanager.com/quick-start-authors)
- [Creating Packages](https://tbxmanager.com/creating-packages)
- [Command Reference](https://tbxmanager.com/commands)
- [Troubleshooting](https://tbxmanager.com/troubleshooting)
- [Contributing](https://tbxmanager.com/contributing)

## Contributing

### Packages

[Submit packages](https://github.com/MarekWadinger/tbxmanager-registry/issues/new?template=submit-package.yml) via the registry issue form. Registry collaborators can also use the [tbxmanager-publish](https://github.com/MarekWadinger/tbxmanager-publish) action for automation.

### Client

1. Fork this repo
2. Create a feature branch from `dev`
3. Make changes and add tests
4. Open a PR to `dev`

## License

[MIT](LICENSE)
