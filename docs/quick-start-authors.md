# Quick Start for Package Authors

Publish your MATLAB toolbox to [tbxmanager](https://tbxmanager.com) in 3 steps. If you don't have tbxmanager yet, see [Getting Started](getting-started.md).

## Step 1: Add `tbxmanager.json`

Run `tbxmanager init` in your project directory to generate the metadata file:

```matlab
>> cd my-toolbox
>> tbxmanager init
Created tbxmanager.json
```

Then edit the generated `tbxmanager.json` to match your package:

```json
{
  "name": "my-toolbox",
  "version": "1.0.0",
  "description": "A useful MATLAB toolbox",
  "platforms": {
    "all": ""
  }
}
```

!!! tip
    You can also create `tbxmanager.json` manually if you don't have tbxmanager installed yet.

Set `platforms` to `"all"` for pure MATLAB packages. If you distribute compiled MEX files, use platform-specific keys (`win64`, `maci64`, `maca64`, `glnxa64`) instead.

The `platforms` URLs will be filled in automatically by the publish action — leave them empty or as placeholders.

## Step 2: Add the Publish Workflow

Copy this file to `.github/workflows/tbxmanager-publish.yml`:

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

Then add a `TBXMANAGER_REGISTRY_TOKEN` secret to your repo (Settings > Secrets). This should be a GitHub Personal Access Token with permission to create PRs on the [tbxmanager-registry](https://github.com/MarekWadinger/tbxmanager-registry).

## Step 3: Create a Release

```bash
git tag v1.0.0
git push --tags
```

Then create a GitHub Release from the tag. The publish action will automatically:

1. Build a zip archive of your package
2. Upload it to the release
3. Compute SHA256 hashes
4. Open a PR to the tbxmanager registry

Once the PR is merged, your package is live:

```matlab
tbxmanager install my-toolbox
```

## What Happens Next

```text
git tag v1.0.0 && git push --tags
         |
         v
  Create GitHub Release
         |
         v
  tbxmanager-publish action runs:
    - Builds zip from repo (excluding .git, tests, docs)
    - Uploads archive to release assets
    - Computes SHA256 hash
    - Converts tbxmanager.json to registry format
    - Opens PR to MarekWadinger/tbxmanager-registry
         |
         v
  CI validates (JSON, URLs, SHA256)
         |
         v
  Merged (auto for updates, reviewed for first submission)
         |
         v
  Package appears in: tbxmanager search my-toolbox
```

## Updating Your Package

1. Update `version` in `tbxmanager.json`
2. Tag and release: `git tag v1.1.0 && git push --tags`
3. Create a GitHub Release — the action handles the rest

New versions are added alongside existing ones. Users can install specific versions with `tbxmanager install my-toolbox@>=1.1`.

## Optional: Customize What Gets Packaged

Add a `publish` section to `tbxmanager.json` to control what goes into the archive:

```json
{
  "name": "my-toolbox",
  "version": "1.0.0",
  "description": "A useful MATLAB toolbox",
  "platforms": { "all": "" },
  "publish": {
    "exclude": [".git", ".github", "tests", "docs", "benchmarks"]
  }
}
```

## MEX Packages (Platform-Specific)

If your package includes compiled MEX files, you need to pre-build archives for each platform:

1. Build MEX files for each target platform
2. Create archives in a `dist/` directory:
    - `dist/my-toolbox-win64.zip`
    - `dist/my-toolbox-maci64.zip`
    - `dist/my-toolbox-maca64.zip`
    - `dist/my-toolbox-glnxa64.zip`
3. Update `tbxmanager.json`:

```json
{
  "platforms": {
    "win64": "",
    "maci64": "",
    "maca64": "",
    "glnxa64": ""
  }
}
```

The publish action will upload these archives and compute SHA256 hashes automatically.

## Next Steps

- [Full metadata reference](creating-packages.md) for all `tbxmanager.json` fields
- [Commands reference](commands.md) for all tbxmanager CLI commands
- [Contributing](contributing.md) to learn about the registry structure
