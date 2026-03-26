---
hide:
  - navigation
  - toc
---

# tbxmanager

**A modern package manager for MATLAB** with dependency resolution, lockfiles, and a community registry.

```matlab
websave('tbxmanager.m', 'https://tbxmanager.com/tbxmanager.m');
tbxmanager
savepath
```

[Get Started](getting-started.md){ .md-button .md-button--primary }
[Browse Packages](https://github.com/kvasnica/tbxmanager-registry){ .md-button }

---

<div class="grid cards" markdown>

-   :material-download:{ .lg .middle } **One-Line Install**

    ---

    Download a single file and you're ready. No compilation, no prerequisites beyond MATLAB R2022a+.

-   :material-source-branch:{ .lg .middle } **Dependency Resolution**

    ---

    Automatically resolves and installs package dependencies with version constraint satisfaction.

-   :material-lock:{ .lg .middle } **Reproducible Environments**

    ---

    Lock exact versions with `tbxmanager lock`. Share `tbxmanager.lock` for identical setups across machines.

-   :material-account-group:{ .lg .middle } **Community Registry**

    ---

    Open package registry. Anyone can contribute packages via pull request. CI validates every submission.

-   :material-monitor:{ .lg .middle } **Cross-Platform**

    ---

    Windows, macOS (Intel & Apple Silicon), and Linux. Platform-specific packages resolved automatically.

-   :material-shield-check:{ .lg .middle } **Integrity Verification**

    ---

    Every download verified with SHA256 checksums. No tampered packages reach your MATLAB path.

</div>

## Quick Start

```matlab
% Install a package
tbxmanager install mpt

% Search for packages
tbxmanager search optimization

% List installed packages
tbxmanager list

% Update all packages
tbxmanager update

% Create reproducible project dependencies
tbxmanager init
tbxmanager lock
tbxmanager sync
```
