# Troubleshooting

Common issues when publishing and using tbxmanager packages.

## Publishing Issues

### CI says "URL unreachable"

The download URL returned a non-200 status during validation.

**Common causes:**

- Release assets are not yet uploaded when the publish action runs. Make sure the action triggers on `release: [published]`, not `push: tags`.
- The repository is private. Download URLs must be publicly accessible.
- GitHub Releases URL has a typo. Double-check the tag name in the URL.

### SHA256 mismatch

The SHA256 hash in the registry does not match the downloaded archive.

**Common causes:**

- You rebuilt the archive after computing the hash. Always compute the hash from the final archive.
- Use the automated publish action to avoid this entirely — it computes hashes automatically.

### "Package name must match directory"

The `name` field in your `package.json` does not match the directory name under `packages/`.

**Fix:** Ensure `packages/my-toolbox/package.json` has `"name": "my-toolbox"`.

### "Invalid MATLAB version constraint"

MATLAB constraints must match the format `>=R2022a` or `==R2024b`.

**Common mistakes:**

- Extra space: `>= R2022a` (no space allowed)
- Missing `R`: `>=2022a` (must include `R` prefix)
- Wrong case: `>=r2022a` (must be uppercase `R`)

### "Invalid version format"

Versions must be semver: `MAJOR.MINOR` or `MAJOR.MINOR.PATCH`.

**Invalid:** `v1.0.0` (no `v` prefix), `1` (need at least `MAJOR.MINOR`), `1.0.0-beta` (no pre-release tags).

## Installation Issues

### "Package not found in any index"

```matlab
tbxmanager search my-toolbox  % verify the package exists
tbxmanager source list         % check configured sources
```

If the source list is empty, add the default:

```matlab
tbxmanager source add https://kvasnica.github.io/tbxmanager-registry/index.json
```

### "No version satisfies constraint for platform"

The package does not have an archive for your platform (e.g., macOS Apple Silicon).

```matlab
tbxmanager info my-toolbox  % check available platforms per version
```

Contact the package author to request your platform.

### SHA256 verification failed during install

The downloaded archive does not match the expected hash. This could mean:

- The archive was modified after publishing (unlikely for GitHub Releases)
- Network corruption during download

**Fix:** Clear the cache and retry:

```matlab
tbxmanager cache clean
tbxmanager install my-toolbox
```

### "DEPRECATED" warning during install

The package author has deprecated this package. The warning message usually suggests an alternative:

```text
Warning: Package 'old-pkg' is deprecated: Use new-pkg instead
```

You can still install it, but consider migrating to the suggested replacement.

### Version marked as "YANKED"

A yanked version has a known issue and is hidden from the resolver. If you need it anyway, pin the exact version:

```matlab
tbxmanager install my-toolbox@==1.0.0
```

## Getting Help

- **tbxmanager client issues:** [kvasnica/tbxmanager](https://github.com/kvasnica/tbxmanager/issues)
- **Registry/package issues:** [kvasnica/tbxmanager-registry](https://github.com/kvasnica/tbxmanager-registry/issues)
- **Publish action issues:** [kvasnica/tbxmanager-publish](https://github.com/kvasnica/tbxmanager-publish/issues)
