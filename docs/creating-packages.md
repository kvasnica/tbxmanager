# Creating Packages

## Package Metadata

Create a `tbxmanager.json` in your repository root:

```json
{
  "name": "my-toolbox",
  "version": "1.0.0",
  "description": "A useful MATLAB toolbox",
  "homepage": "https://github.com/you/my-toolbox",
  "license": "MIT",
  "authors": ["Your Name <your@email.com>"],
  "matlab": ">=R2022a",
  "dependencies": {
    "some-other-pkg": ">=2.0"
  },
  "platforms": {
    "all": "https://github.com/you/my-toolbox/releases/download/v1.0.0/my-toolbox-all.zip"
  }
}
```

### Fields

| Field | Required | Description |
| ----- | -------- | ----------- |
| `name` | Yes | Lowercase, alphanumeric, hyphens, underscores |
| `version` | Yes | Semver: `MAJOR.MINOR.PATCH` |
| `description` | Yes | Short description (max 200 chars) |
| `platforms` | Yes | At least one platform with download URL |
| `homepage` | No | Project URL |
| `license` | No | SPDX identifier (MIT, GPL-3.0, BSD-3-Clause, etc.) |
| `authors` | No | List of `"Name <email>"` strings |
| `matlab` | No | MATLAB version constraint (e.g., `>=R2022a`) |
| `dependencies` | No | Map of package names to version constraints |

### Platforms

| Platform | Description |
| -------- | ----------- |
| `all` | Pure MATLAB code (no MEX files) |
| `win64` | Windows 64-bit |
| `maci64` | macOS Intel |
| `maca64` | macOS Apple Silicon |
| `glnxa64` | Linux 64-bit |

Use `all` if your package is pure MATLAB. Provide platform-specific archives if you include MEX files.

## Building Archives

Create a zip archive containing your package files:

```bash
# For pure MATLAB packages
cd my-toolbox
zip -r ../my-toolbox-all.zip . -x '.git/*' -x '.github/*' -x 'tbxmanager.json'

# For platform-specific packages (with MEX files)
zip -r ../my-toolbox-maci64.zip . -x '.git/*' -x '*.mexw64' -x '*.mexa64'
```

## Hosting on GitHub Releases

1. Tag your release: `git tag v1.0.0 && git push --tags`
2. Go to your repo's Releases page
3. Create a new release from the tag
4. Upload your archive(s)
5. Use the release asset URLs in your `tbxmanager.json`

## Computing SHA256

The registry requires SHA256 hashes for integrity verification:

```bash
# macOS
shasum -a 256 my-toolbox-all.zip

# Linux
sha256sum my-toolbox-all.zip

# Windows (PowerShell)
Get-FileHash my-toolbox-all.zip -Algorithm SHA256
```

## Submitting to the Registry

1. Fork [kvasnica/tbxmanager-registry](https://github.com/kvasnica/tbxmanager-registry)
2. Create `packages/my-toolbox/package.json`:

```json
{
  "name": "my-toolbox",
  "description": "A useful MATLAB toolbox",
  "homepage": "https://github.com/you/my-toolbox",
  "license": "MIT",
  "authors": ["Your Name <your@email.com>"],
  "versions": {
    "1.0.0": {
      "matlab": ">=R2022a",
      "dependencies": {},
      "platforms": {
        "all": {
          "url": "https://github.com/you/my-toolbox/releases/download/v1.0.0/my-toolbox-all.zip",
          "sha256": "your-sha256-hash-here"
        }
      },
      "released": "2026-03-25"
    }
  }
}
```

1. Open a pull request
1. CI automatically validates your submission
1. Once merged, the package appears in the registry

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

## Updating Your Package

To add a new version, update your `package.json` in the registry with a new version entry and open a PR.
