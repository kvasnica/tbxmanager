# Creating Packages

## The Fast Way: Automated Publishing

The easiest way to publish a MATLAB package is to run `tbxmanager publish` from your package directory. Alternatively, [submit via the registry issue form](https://github.com/MarekWadinger/tbxmanager-registry/issues/new?template=submit-package.yml). See the [Quick Start](quick-start-authors.md) for a full guide.

With the publish action, you only maintain `tbxmanager.json` in your repo — the action handles archive building, SHA256 hashing, and registry submission automatically.

## Package Metadata

Run [`tbxmanager init`](getting-started.md) in your project directory to generate the metadata file, then edit it:

```matlab
>> tbxmanager init
Created tbxmanager.json
```

The generated `tbxmanager.json` looks like this (customize the fields for your package):

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

!!! tip
    You can also create `tbxmanager.json` manually if you don't have tbxmanager installed yet.

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
| `publish` | No | Publishing config (see below) |

### Platforms

| Platform | Description |
| -------- | ----------- |
| `all` | Pure MATLAB code (no MEX files) |
| `win64` | Windows 64-bit |
| `maci64` | macOS Intel |
| `maca64` | macOS Apple Silicon |
| `glnxa64` | Linux 64-bit |

Use `all` if your package is pure MATLAB. Provide platform-specific archives if you include MEX files.

### Publish Configuration

Optional section for the automated publish action:

```json
{
  "publish": {
    "exclude": [".git", ".github", "tests", "docs", "benchmarks"],
    "archive_dir": "dist"
  }
}
```

| Field | Default | Description |
| ----- | ------- | ----------- |
| `exclude` | `.git`, `.github`, `tests`, `docs`, `tbxmanager.json` | Patterns to exclude from auto-built archives |
| `archive_dir` | `dist` | Directory for pre-built platform archives |

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

## Deprecation and Yanking

### Deprecating a Package

To mark an entire package as deprecated, add a `"deprecated"` field to the registry entry:

```json
{
  "name": "old-toolbox",
  "deprecated": "Use new-toolbox instead",
  ...
}
```

Users will see a warning during `install`, `search`, and `info` but can still install the package.

### Yanking a Version

To mark a specific version as having a critical issue:

```json
{
  "versions": {
    "1.0.0": {
      "yanked": "Critical bug in dependency resolution",
      ...
    }
  }
}
```

Yanked versions are skipped by the resolver. Users can still install them with an explicit pin: `tbxmanager install pkg@==1.0.0`.

Submit deprecation or yank changes as a PR to the registry.

---

## Advanced: Manual Submission

If you prefer not to use the automated publish action, you can submit packages manually.

### Building Archives

Create a zip archive containing your package files:

```bash
# For pure MATLAB packages
cd my-toolbox
zip -r ../my-toolbox-all.zip . -x '.git/*' -x '.github/*' -x 'tbxmanager.json'

# For platform-specific packages (with MEX files)
zip -r ../my-toolbox-maci64.zip . -x '.git/*' -x '*.mexw64' -x '*.mexa64'
```

### Hosting on GitHub Releases

1. Tag your release: `git tag v1.0.0 && git push --tags`
2. Go to your repo's Releases page
3. Create a new release from the tag
4. Upload your archive(s)
5. Use the release asset URLs in your registry submission

### Computing SHA256

The registry requires SHA256 hashes for integrity verification:

=== "macOS"
    ```bash
    shasum -a 256 my-toolbox-all.zip
    ```

=== "Linux"
    ```bash
    sha256sum my-toolbox-all.zip
    ```

=== "Windows (PowerShell)"
    ```powershell
    Get-FileHash my-toolbox-all.zip -Algorithm SHA256
    ```

!!! tip
    Use the converter script to generate the registry format from your `tbxmanager.json`:
    ```bash
    python scripts/convert_to_registry.py \
      --input tbxmanager.json \
      --output packages/my-toolbox/package.json \
      --sha256 all=abc123... \
      --released 2026-03-28
    ```

### Submitting to the Registry

1. Fork [MarekWadinger/tbxmanager-registry](https://github.com/MarekWadinger/tbxmanager-registry)
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

### Updating (Manual)

To add a new version, edit your `package.json` in the registry with a new version entry and open a PR.
