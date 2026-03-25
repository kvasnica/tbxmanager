# Getting Started

## Prerequisites

- **MATLAB R2022a** or newer

## Installation

Run these three lines in the MATLAB Command Window:

```matlab
websave('tbxmanager.m', 'https://tbxmanager.com/tbxmanager.m');
tbxmanager
savepath
```

This downloads the package manager, initializes its storage directory (`~/.tbxmanager/`), and saves the MATLAB path.

## Auto-Restore on Startup

Add this line to your `startup.m` file so installed packages are available every time MATLAB starts:

```matlab
tbxmanager restorepath
```

To find or create your `startup.m`:

```matlab
edit(fullfile(userpath, 'startup.m'))
```

## Install Your First Package

```matlab
tbxmanager install mpt
```

This resolves dependencies, downloads archives, verifies SHA256 integrity, and adds everything to your MATLAB path.

## Search for Packages

```matlab
tbxmanager search optimization
```

## List Installed Packages

```matlab
tbxmanager list
```

Shows a table with package names, installed versions, latest available versions, and enabled status.

## Update Packages

```matlab
% Update all
tbxmanager update

% Update a specific package
tbxmanager update mpt
```

## Uninstall

```matlab
tbxmanager uninstall mpt
```

## Project Dependencies

For reproducible projects, create a `tbxmanager.json` in your project root:

```matlab
tbxmanager init
```

This creates a template. Edit it to declare your dependencies:

```json
{
  "name": "my-project",
  "matlab": ">=R2022a",
  "dependencies": {
    "mpt": ">=3.0",
    "cddmex": ">=1.0"
  }
}
```

Then generate a lockfile:

```matlab
tbxmanager lock
```

Team members clone your repo and run:

```matlab
tbxmanager sync
```

This installs the exact versions from `tbxmanager.lock`, ensuring identical environments.

## Self-Update

Keep tbxmanager itself up to date:

```matlab
tbxmanager selfupdate
```
