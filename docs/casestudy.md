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

## Step 2: Add the Publish Workflow

Create `.github/workflows/tbxmanager-publish.yml`:

```yaml
name: Publish to tbxmanager

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: MarekWadinger/tbxmanager-publish@v1
        with:
          registry-token: ${{ secrets.TBXMANAGER_REGISTRY_TOKEN }}
```

That's the entire workflow -- 15 lines. It triggers when you create a GitHub Release.

## Step 3: Create a Registry Token

The publish action needs permission to open PRs on the tbxmanager registry. You create this once and reuse it across all your packages.

1. Go to [GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new)
2. Create a new token with:
    - **Token name:** `tbxmanager-publish`
    - **Expiration:** 1 year (or your preference)
    - **Repository access:** Select `MarekWadinger/tbxmanager-registry`
    - **Permissions:** Contents (Read and write), Pull requests (Read and write)
3. Copy the token
4. Go to your package repo: **Settings > Secrets and variables > Actions**
5. Click **New repository secret**
    - **Name:** `TBXMANAGER_REGISTRY_TOKEN`
    - **Value:** paste the token

## Step 4: Commit and Push

```bash
cd RLS_identification

git add tbxmanager.json .github/workflows/tbxmanager-publish.yml
git commit -m "feat: add tbxmanager package publishing"
git push
```

## Step 5: Create a Release

### Option A: GitHub CLI

```bash
git tag v1.0.0
git push --tags
gh release create v1.0.0 --title "v1.0.0" --notes "Initial tbxmanager release"
```

### Option B: GitHub Web UI

1. Go to your repo on GitHub
2. Click **Releases** > **Create a new release**
3. Choose tag: type `v1.0.0`, select "Create new tag on publish"
4. Title: `v1.0.0`
5. Click **Publish release**

## What Happens Automatically

After you publish the release, the GitHub Action runs and does everything else:

```text
You: Create GitHub Release v1.0.0
         |
         v
Action: Reads tbxmanager.json
  name = rls-identification
  version = 1.0.0
         |
         v
Action: Builds rls-identification-all.zip
  Includes: functions/, main.m, LICENSE, README.md
  Excludes: .git, .github, *.mat, *.slx
         |
         v
Action: Uploads zip to release assets
  URL: github.com/MarekWadinger/RLS_identification/releases/download/v1.0.0/rls-identification-all.zip
         |
         v
Action: Computes SHA256 hash
  sha256 = a1b2c3d4...
         |
         v
Action: Converts tbxmanager.json to registry format
  Creates packages/rls-identification/package.json
         |
         v
Action: Opens PR to MarekWadinger/tbxmanager-registry
  Title: "New package: rls-identification@1.0.0"
         |
         v
Registry CI: Validates JSON schema, checks URL, verifies SHA256
         |
         v
Maintainer merges PR (auto-merge for updates after first approval)
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
2. Commit and push your changes
3. Create a new release:

```bash
git tag v1.1.0
git push --tags
gh release create v1.1.0 --title "v1.1.0" --notes "Added feature X"
```

The action opens a new PR to the registry. Since the package already exists, it gets auto-merged (no manual review needed).

Users update with:

```matlab
>> tbxmanager update rls-identification
```

## Repository Structure (After)

After adding tbxmanager support, only 2 files were added:

```text
RLS_identification/
  .github/
    workflows/
      tbxmanager-publish.yml   <-- NEW (15 lines)
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

No changes to any existing files. No build system. No CI configuration beyond the 15-line workflow.

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

The action uploads each platform archive separately.

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

Check the Actions tab in your repo. Common issues:

- **`tbxmanager.json not found`** -- file must be in the repo root
- **`Archive not found`** -- for platform-specific packages, pre-build archives in `dist/`
- **`403 on PR creation`** -- token lacks write permissions to the registry
- **`SHA256 mismatch`** -- re-run the release (archive was modified between upload and hash)

## Summary

| What | Where | How often |
| ---- | ----- | --------- |
| `tbxmanager.json` | Your repo root | Once (update `version` per release) |
| Publish workflow | `.github/workflows/` | Once (copy and forget) |
| Registry token | Repo secret | Once (renew when expired) |
| Create release | GitHub UI or CLI | Each time you publish |
