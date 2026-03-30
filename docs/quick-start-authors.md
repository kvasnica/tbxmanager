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
  "authors": ["YourGitHubUsername"],
  "license": "MIT",
  "homepage": "https://github.com/you/my-toolbox",
  "matlab": ">=R2022a",
  "platforms": {
    "all": {}
  },
  "dependencies": {}
}
```

!!! tip
    You can also create `tbxmanager.json` by hand if you don't have tbxmanager installed yet.

Set `platforms` to `"all"` for pure MATLAB packages. If you distribute compiled MEX files, use platform-specific keys (`win64`, `maci64`, `maca64`, `glnxa64`) instead.

## Step 2: Create a GitHub Release

1. Zip your package (exclude `.git`, tests, docs, etc.)
1. Tag your version and push:

    ```bash
    git tag v1.0.0
    git push --tags
    ```

1. Go to your repo on GitHub, click **Releases** > **Create a new release**
1. Select the tag, add a title, and **attach your zip file** as a release asset
1. Click **Publish release**

## Step 3: Submit to the Registry

1. Go to [tbxmanager-registry > Issues > New Issue](https://github.com/MarekWadinger/tbxmanager-registry/issues/new/choose)
1. Click **"Submit Package"**
1. Fill in your **Repository URL** and **Release tag**
1. Click **Submit new issue**

That's it! A bot will automatically:

- Fetch your `tbxmanager.json`
- Download your release archive
- Compute the SHA256 hash
- Create a pull request to the registry

Once a maintainer merges the PR, your package is live:

```matlab
tbxmanager install my-toolbox
```

## Updating Your Package

1. Update `version` in `tbxmanager.json`
1. Create a new release with the updated archive
1. Submit another issue on the registry (same form)

New versions are added alongside existing ones. Users can install specific versions with `tbxmanager install my-toolbox@>=1.1`.

## Optional: Customize What Gets Packaged

Add a `publish` section to `tbxmanager.json` to control what goes into the archive:

```json
{
  "publish": {
    "exclude": [".git", ".github", "tests", "docs", "benchmarks"]
  }
}
```

## MEX Packages (Platform-Specific)

If your package includes compiled MEX files, create separate archives per platform:

- `my-toolbox-win64.zip`
- `my-toolbox-maci64.zip`
- `my-toolbox-maca64.zip`
- `my-toolbox-glnxa64.zip`

Attach all of them to your GitHub Release and select the appropriate platform in the submission form.

## Even Faster: `tbxmanager publish`

If you have tbxmanager installed, you can do everything in one command:

```matlab
>> cd my-toolbox
>> tbxmanager publish
```

This builds the archive, creates the GitHub release, uploads it, and submits to the registry — all automatically. Requires a GitHub token with `public_repo` scope (prompted on first use).

## Next Steps

- [Case Study](casestudy.md) -- real-world example with RLS_identification
- [Full metadata reference](creating-packages.md) for all `tbxmanager.json` fields
- [Commands reference](commands.md) for all tbxmanager CLI commands
