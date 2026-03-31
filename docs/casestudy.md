# Case Study: Publishing RLS Identification to tbxmanager

This guide walks through a real example of publishing an existing MATLAB repository to tbxmanager. We use [RLS_identification](https://github.com/MarekWadinger/RLS_identification) -- a Recursive Least Squares algorithm for system parameter identification.

## Before You Start

You need:

- [tbxmanager](https://tbxmanager.com) installed in MATLAB (see [Getting Started](getting-started.md))
- A GitHub repository with your MATLAB code
- A GitHub account
- 10 minutes

## Repository Structure (Before)

Here's what the repo looks like before any tbxmanager changes:

```text
RLS_identification/
  functions/
    preprocessData.m
    recursiveLeastSquares.m
    setPeriod.m
  .gitignore
  LICENSE
  README.md
  example_fan_control.mat
  imc.slx
  main.m
```

A standard MATLAB project -- functions in a folder, a demo script, some data files, and a Simulink model.

## Step 1: Add `tbxmanager.json`

The quickest way to generate the metadata file is to run `tbxmanager init` inside your project directory:

```matlab
>> cd RLS_identification
>> tbxmanager init
Created tbxmanager.json
```

This creates a `tbxmanager.json` template that you then edit to match your package. For RLS_identification, the final file looks like this:

```json
{
  "name": "rls-identification",
  "version": "1.0.0",
  "description": "Recursive Least Squares algorithm for system parameter identification",
  "authors": ["MarekWadinger"],
  "license": "MIT",
  "homepage": "https://github.com/MarekWadinger/RLS_identification",
  "matlab": ">=R2019b",
  "platforms": {
    "all": {}
  },
  "dependencies": {},
  "publish": {
    "exclude": [".git", ".github", "tests", "docs", "*.mat", "*.slx"]
  }
}
```

### Field-by-field explanation

| Field | Value | Why |
| ----- | ----- | --- |
| `name` | `rls-identification` | Lowercase, hyphens. This is the install name: `tbxmanager install rls-identification` |
| `version` | `1.0.0` | [Semantic versioning](https://semver.org). Bump this each release. |
| `description` | Short text | Shown in `tbxmanager search` results |
| `authors` | `["MarekWadinger"]` | Your GitHub username(s) |
| `license` | `MIT` | Must match your LICENSE file |
| `homepage` | Repo URL | Shown in `tbxmanager info rls-identification` |
| `matlab` | `>=R2019b` | Minimum MATLAB version. This repo uses `arguments` blocks (R2019b+). |
| `platforms.all` | `{}` | Pure MATLAB code, no MEX files. Works on all platforms. |
| `dependencies` | `{}` | No tbxmanager dependencies. If you needed `mpt`, you'd write `{"mpt": ">=3.0"}` |
| `publish.exclude` | List of patterns | Files/folders to exclude from the archive. Keep the zip clean -- users don't need `.mat` example data or `.slx` Simulink models. |

### How to determine `matlab` version

Check which features your code uses:

| Feature | Minimum MATLAB |
| ------- | -------------- |
| `arguments` blocks | R2019b |
| `yline` / `xline` | R2018b |
| `string` arrays | R2016b |
| `jsondecode` | R2016b |
| `dictionary` type | R2022b |

Pick the highest minimum from features you use. For RLS_identification, `arguments` blocks require **R2019b**.

## Step 2: Commit and Push

```bash
cd RLS_identification

git add tbxmanager.json
git commit -m "feat: add tbxmanager package metadata"
git push
```

That's the only file you need to add to your repo.

## Step 3: Create a GitHub Release

1. Zip your package (exclude `.git`, tests, data files you don't want distributed):

    ```bash
    zip -r rls-identification.zip functions/ main.m LICENSE README.md
    ```

1. Tag and push:

    ```bash
    git tag v1.0.0
    git push --tags
    ```

1. Go to your repo on GitHub, click **Releases** > **Create a new release**
1. Select the `v1.0.0` tag, add a title
1. **Attach `rls-identification.zip`** as a release asset
1. Click **Publish release**

## Step 4: Submit to the Registry

1. Go to [tbxmanager-registry > Issues > New Issue](https://github.com/MarekWadinger/tbxmanager-registry/issues/new/choose)
1. Click **"Submit Package"**
1. Fill in:
    - **Repository URL:** `https://github.com/MarekWadinger/RLS_identification`
    - **Release tag:** `v1.0.0`
    - **Platform:** `all (pure MATLAB, no MEX files)`
1. Click **Submit new issue**

## What Happens Automatically

After you submit the issue, a bot takes over:

```text
You: Fill in the submission form
         |
         v
Bot: Fetches tbxmanager.json from your repo at v1.0.0
  name = rls-identification
  version = 1.0.0
         |
         v
Bot: Downloads rls-identification.zip from your release
         |
         v
Bot: Computes SHA256 hash
  sha256 = a1b2c3d4...
         |
         v
Bot: Converts tbxmanager.json to registry format
  Creates packages/rls-identification/package.json
         |
         v
Bot: Opens PR to MarekWadinger/tbxmanager-registry
  Title: "Add rls-identification@1.0.0"
         |
         v
Registry CI: Validates JSON, checks URL
         |
         v
Maintainer merges PR
         |
         v
Package is live!
```

## After Publishing: User Experience

Once the registry PR is merged, anyone can install your package:

```matlab
>> tbxmanager install rls-identification
Resolving dependencies...
  rls-identification 1.0.0
Downloading rls-identification@1.0.0... done
Verifying SHA256... ok
Installing rls-identification@1.0.0... done

>> tbxmanager info rls-identification
rls-identification 1.0.0
  Recursive Least Squares algorithm for system parameter identification
  License: MIT
  Homepage: https://github.com/MarekWadinger/RLS_identification
  MATLAB: >=R2019b
  Platforms: all
```

## Publishing Updates

When you improve your package:

1. Update `version` in `tbxmanager.json` (e.g., `1.0.0` -> `1.1.0`)
1. Commit and push your changes
1. Create a new release with the updated zip
1. Submit another issue on the registry (same form, new tag)

Users update with:

```matlab
>> tbxmanager update rls-identification
```

## Repository Structure (After)

After adding tbxmanager support, only 1 file was added:

```text
RLS_identification/
  functions/
    preprocessData.m
    recursiveLeastSquares.m
    setPeriod.m
  .gitignore
  LICENSE
  README.md
  example_fan_control.mat
  imc.slx
  main.m
  tbxmanager.json              <-- NEW (14 lines)
```

No changes to any existing files. No build system. No CI configuration needed.

## Common Questions

### My package has dependencies on other tbxmanager packages

Add them to `dependencies`:

```json
"dependencies": {
  "mpt": ">=3.0",
  "yalmip": ">=R20200930"
}
```

tbxmanager resolves the full dependency tree automatically.

### My package has compiled MEX files

Use platform-specific keys instead of `all`:

```json
"platforms": {
  "win64": {},
  "maci64": {},
  "maca64": {},
  "glnxa64": {}
}
```

Pre-build your MEX archives and place them in `dist/`:

```text
dist/
  my-package-win64.zip
  my-package-maci64.zip
  my-package-maca64.zip
  my-package-glnxa64.zip
```

Attach all archives to your GitHub Release. Select the corresponding platform in the submission form.

### I want to deprecate my package

Add `deprecated` to your registry entry:

```json
"deprecated": "Use new-package instead"
```

Users see a warning on install, but can still use it. To deprecate a specific version (yank), add `yanked` to that version entry.

### I want to exclude more files from the archive

Edit the `publish.exclude` list:

```json
"publish": {
  "exclude": [".git", ".github", "tests", "docs", "benchmarks", "*.mat", "*.slx", "*.fig"]
}
```

### My token expired

Create a new fine-grained token (Step 3) and update the `TBXMANAGER_REGISTRY_TOKEN` secret in your repo settings.

### The action failed

Check the bot's comment on your submission issue. Common issues:

- **`tbxmanager.json not found`** -- file must be in the repo root at the tagged commit
- **`No release found`** -- create a GitHub Release for the tag first
- **`No archive attached`** -- attach a `.zip` file to your GitHub Release

## Summary

| What | Where | How often |
| ---- | ----- | --------- |
| `tbxmanager.json` | Your repo root | Once (update `version` per release) |
| Create release + zip | GitHub Releases | Each time you publish |
| Submit issue | tbxmanager-registry | Each time you publish |
