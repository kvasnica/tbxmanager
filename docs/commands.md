# Command Reference

## install

Install one or more packages with automatic dependency resolution.

```matlab
tbxmanager install pkg1 pkg2
tbxmanager install mpt@>=3.0
```

Packages are downloaded to `~/.tbxmanager/cache/`, verified with SHA256, extracted to `~/.tbxmanager/packages/`, and added to the MATLAB path.

## uninstall

Remove installed packages.

```matlab
tbxmanager uninstall pkg1 pkg2
```

Warns if other installed packages depend on the one being removed.

## update

Update packages to their latest available versions.

```matlab
tbxmanager update          % update all
tbxmanager update mpt      % update specific package
```

## list

Show installed packages with version and status information.

```matlab
tbxmanager list
```

Displays: name, installed version, latest available, enabled/disabled status.

## search

Search available packages by name or description.

```matlab
tbxmanager search optimization
tbxmanager search linear
```

## info

Show detailed information about a package.

```matlab
tbxmanager info mpt
```

Displays: description, homepage, license, authors, available versions, dependencies, supported platforms.

## lock

Generate or update a lockfile from project dependencies.

```matlab
tbxmanager lock
```

Reads `tbxmanager.json` from the current directory, resolves all dependencies for the current platform, and writes `tbxmanager.lock` with pinned versions and SHA256 hashes.

## sync

Install packages from a lockfile for reproducible environments.

```matlab
tbxmanager sync
```

Reads `tbxmanager.lock` from the current directory and installs the exact versions specified. Verifies SHA256 integrity of all packages.

## init

Create a `tbxmanager.json` template in the current directory.

```matlab
tbxmanager init
```

## selfupdate

Update tbxmanager itself to the latest version.

```matlab
tbxmanager selfupdate
```

## source

Manage package index sources.

```matlab
tbxmanager source list                    % show configured sources
tbxmanager source add https://...         % add a source
tbxmanager source remove https://...      % remove a source
```

The default source is `https://kvasnica.github.io/tbxmanager-registry/index.json`.

## enable / disable

Manage which installed packages are on the MATLAB path.

```matlab
tbxmanager enable mpt
tbxmanager disable mpt
```

## restorepath

Restore all enabled packages to the MATLAB path. Add to `startup.m` for automatic setup.

```matlab
tbxmanager restorepath
```

## require

Assert that packages are installed and enabled. Useful in scripts.

```matlab
tbxmanager require mpt cddmex
```

Throws an error if any listed package is not available.

## cache

Manage the download cache.

```matlab
tbxmanager cache list     % show cached archives
tbxmanager cache clean    % remove all cached files
```

Cache location: `~/.tbxmanager/cache/`

## help

Show help text.

```matlab
tbxmanager help
tbxmanager help install
```
