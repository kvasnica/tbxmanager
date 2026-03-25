function tbxmanager(command, varargin)
%TBXMANAGER  Toolbox package manager for MATLAB (v2)
%
%   tbxmanager install pkg1 pkg2@>=1.0 ...
%   tbxmanager uninstall pkg1 pkg2 ...
%   tbxmanager update [pkg1 ...]
%   tbxmanager list
%   tbxmanager search query
%   tbxmanager info pkg
%   tbxmanager lock
%   tbxmanager sync
%   tbxmanager init
%   tbxmanager selfupdate
%   tbxmanager source add|remove|list [url]
%   tbxmanager enable pkg1 ...
%   tbxmanager disable pkg1 ...
%   tbxmanager restorepath
%   tbxmanager require pkg1 ...
%   tbxmanager cache clean|list
%   tbxmanager help [command]
%
%   For more information: tbxmanager help

% Copyright (c) 2012-2026 Michal Kvasnica
% tbxmanager v2.0

    if nargin == 0
        command = "help";
    end
    command = string(command);
    args = string(varargin);

    tbx_setup();

    switch lower(command)
        case "install"
            main_install(args);
        case "uninstall"
            main_uninstall(args);
        case "update"
            main_update(args);
        case "list"
            main_list(args);
        case "search"
            main_search(args);
        case "info"
            main_info(args);
        case "lock"
            main_lock(args);
        case "sync"
            main_sync(args);
        case "init"
            main_init(args);
        case "selfupdate"
            main_selfupdate(args);
        case "source"
            main_source(args);
        case "enable"
            main_enable(args);
        case "disable"
            main_disable(args);
        case "restorepath"
            main_restorepath(args);
        case "require"
            main_require(args);
        case "cache"
            main_cache(args);
        case "help"
            main_help(args);
        case "internal__"
            main_internal(args);
        otherwise
            tbx_printError("Unknown command '%s'. Type 'tbxmanager help' for usage.", command);
    end
end

%% ========================================================================
%  Setup, config, platform
%  ========================================================================

function tbx_setup()
%TBX_SETUP  Create ~/.tbxmanager/ directory structure on first run.
    baseDir = tbx_baseDir();
    dirs = {fullfile(baseDir, "packages"), ...
            fullfile(baseDir, "cache"), ...
            fullfile(baseDir, "state"), ...
            fullfile(baseDir, "tmp")};
    for i = 1:numel(dirs)
        if ~isfolder(dirs{i})
            mkdir(dirs{i});
        end
    end
    % Initialize sources.json if missing
    sourcesFile = fullfile(baseDir, "state", "sources.json");
    if ~isfile(sourcesFile)
        s.sources = {"https://kvasnica.github.io/tbxmanager-registry/index.json"};
        tbx_writeJson(sourcesFile, s);
    end
    % Initialize enabled.json if missing
    enabledFile = fullfile(baseDir, "state", "enabled.json");
    if ~isfile(enabledFile)
        s2.packages = struct();
        tbx_writeJson(enabledFile, s2);
    end
    % Detect old-style installation and offer migration
    tbx_migrateOld();
end

function d = tbx_baseDir()
%TBX_BASEDIR  Return the base directory ~/.tbxmanager
%   Respects TBXMANAGER_HOME env var for test isolation.
    d = getenv("TBXMANAGER_HOME");
    if strlength(d) > 0
        return;
    end
    if ispc
        d = fullfile(getenv("USERPROFILE"), ".tbxmanager");
    else
        d = fullfile(getenv("HOME"), ".tbxmanager");
    end
end

function cfg = tbx_config()
%TBX_CONFIG  Load or create config.json
    cfgFile = fullfile(tbx_baseDir(), "config.json");
    if isfile(cfgFile)
        cfg = tbx_readJson(cfgFile);
    else
        cfg = struct();
        cfg.auto_enable = true;
        cfg.confirm_install = true;
        cfg.selfupdate_url = "https://tbxmanager.com/tbxmanager.m";
        tbx_writeJson(cfgFile, cfg);
    end
end

function arch = tbx_platformArch()
%TBX_PLATFORMARCH  Return MATLAB platform architecture string.
    if ismac
        [~, hw] = system("uname -m");
        hw = strtrim(string(hw));
        if hw == "arm64"
            arch = "maca64";
        else
            arch = "maci64";
        end
    elseif ispc
        arch = "win64";
    else
        [~, hw] = system("uname -m");
        hw = strtrim(string(hw));
        if hw == "aarch64"
            arch = "glnxa64";
        else
            arch = "glnxa64";
        end
    end
end

function rel = tbx_matlabRelease()
%TBX_MATLABRELEASE  Return current MATLAB release string, e.g. "R2023b".
    rel = string(version("-release"));
end

function num = tbx_matlabReleaseNum(rel)
%TBX_MATLABRELEASENUM  Convert release string to numeric.
%   "R2022a" -> 2022.0, "R2022b" -> 2022.5
    arguments
        rel (1,1) string
    end
    rel = strip(rel);
    if startsWith(rel, "R", "IgnoreCase", true)
        rel = extractAfter(rel, 1);
    end
    yearStr = extractBefore(rel, strlength(rel));
    suffix = extractAfter(rel, strlength(rel) - 1);
    num = str2double(yearStr);
    if isnan(num)
        error("TBXMANAGER:InvalidRelease", "Cannot parse MATLAB release: %s", rel);
    end
    if lower(suffix) == "b"
        num = num + 0.5;
    end
end

%% ========================================================================
%  JSON / HTTP / SHA256 utilities
%  ========================================================================

function data = tbx_readJson(filePath)
%TBX_READJSON  Read and decode a JSON file.
    arguments
        filePath (1,1) string
    end
    if ~isfile(filePath)
        error("TBXMANAGER:FileNotFound", "JSON file not found: %s", filePath);
    end
    txt = fileread(filePath);
    data = jsondecode(txt);
end

function tbx_writeJson(filePath, data)
%TBX_WRITEJSON  Encode and write a JSON file with pretty formatting.
    arguments
        filePath (1,1) string
        data
    end
    txt = jsonencode(data, "PrettyPrint", true);
    fid = fopen(filePath, "w", "n", "UTF-8");
    if fid == -1
        error("TBXMANAGER:FileWrite", "Cannot write to file: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fwrite(fid, txt, "char");
end

function data = tbx_fetchJson(url)
%TBX_FETCHJSON  Fetch and decode JSON from a URL.
    arguments
        url (1,1) string
    end
    try
        opts = weboptions("Timeout", 30, "ContentType", "json");
        data = webread(url, opts);
    catch ME
        error("TBXMANAGER:FetchFailed", "Failed to fetch %s: %s", url, ME.message);
    end
end

function destPath = tbx_downloadFile(url, destPath)
%TBX_DOWNLOADFILE  Download a file from URL to destPath.
    arguments
        url (1,1) string
        destPath (1,1) string
    end
    tbx_printf("  Downloading %s ...\n", url);
    try
        opts = weboptions("Timeout", 120);
        websave(destPath, url, opts);
    catch ME
        error("TBXMANAGER:DownloadFailed", "Failed to download %s: %s", url, ME.message);
    end
end

function hash = tbx_sha256(filePath)
%TBX_SHA256  Compute SHA-256 hash of a file using Java MessageDigest.
    arguments
        filePath (1,1) string
    end
    md = java.security.MessageDigest.getInstance("SHA-256");
    fis = java.io.FileInputStream(java.io.File(char(filePath)));
    buffer = zeros(1, 8192, "int8");
    while true
        bytesRead = fis.read(buffer);
        if bytesRead == -1
            break;
        end
        md.update(buffer(1:bytesRead));
    end
    fis.close();
    hashBytes = md.digest();
    hexChars = char("0123456789abcdef");
    hashStr = blanks(length(hashBytes) * 2);
    for i = 1:length(hashBytes)
        b = typecast(int8(hashBytes(i)), "uint8");
        hashStr((i-1)*2 + 1) = hexChars(bitshift(b, -4) + 1);
        hashStr((i-1)*2 + 2) = hexChars(bitand(b, 15) + 1);
    end
    hash = string(hashStr);
end

%% ========================================================================
%  Version parsing, comparison, and constraint engine
%  ========================================================================

function parts = tbx_parseVersion(verStr)
%TBX_PARSEVERSION  Parse "1.2.3" -> [1 2 3]. Supports 1, 1.2, 1.2.3.
    arguments
        verStr (1,1) string
    end
    verStr = strip(verStr);
    tokens = split(verStr, ".");
    parts = zeros(1, 3);
    for i = 1:min(numel(tokens), 3)
        val = str2double(tokens(i));
        if isnan(val)
            val = 0;
        end
        parts(i) = val;
    end
end

function result = tbx_compareVersions(v1, v2)
%TBX_COMPAREVERSIONS  Compare two version strings. Returns -1, 0, or 1.
    arguments
        v1 (1,1) string
        v2 (1,1) string
    end
    p1 = tbx_parseVersion(v1);
    p2 = tbx_parseVersion(v2);
    for i = 1:3
        if p1(i) < p2(i)
            result = -1;
            return;
        elseif p1(i) > p2(i)
            result = 1;
            return;
        end
    end
    result = 0;
end

function constraints = tbx_parseConstraint(constraintStr)
%TBX_PARSECONSTRAINT  Parse version constraint string into struct array.
%   Each struct: op (string), version (string).
%   Supports: >=1.0, <2.0, ==1.2.3, ~=1.2, >=1.0,<2.0, *, ""
    arguments
        constraintStr (1,1) string
    end
    constraintStr = strip(constraintStr);
    if constraintStr == "" || constraintStr == "*"
        constraints = struct("op", "*", "version", "0.0.0");
        return;
    end
    % Split on comma for AND constraints
    parts = split(constraintStr, ",");
    constraints = struct("op", {}, "version", {});
    for i = 1:numel(parts)
        p = strip(parts(i));
        if p == "" || p == "*"
            c.op = "*";
            c.version = "0.0.0";
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, "~=")
            % Compatible release: ~=1.2 means >=1.2.0, <2.0.0
            ver = strip(extractAfter(p, "~="));
            vparts = tbx_parseVersion(ver);
            c.op = ">=";
            c.version = ver;
            constraints(end+1) = c; %#ok<AGROW>
            c2.op = "<";
            c2.version = sprintf("%d.0.0", vparts(1) + 1);
            constraints(end+1) = c2; %#ok<AGROW>
        elseif startsWith(p, ">=")
            c.op = ">=";
            c.version = strip(extractAfter(p, ">="));
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, "<=")
            c.op = "<=";
            c.version = strip(extractAfter(p, "<="));
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, "==")
            c.op = "==";
            c.version = strip(extractAfter(p, "=="));
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, "!=")
            c.op = "!=";
            c.version = strip(extractAfter(p, "!="));
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, "<")
            c.op = "<";
            c.version = strip(extractAfter(p, "<"));
            constraints(end+1) = c; %#ok<AGROW>
        elseif startsWith(p, ">")
            c.op = ">";
            c.version = strip(extractAfter(p, ">"));
            constraints(end+1) = c; %#ok<AGROW>
        else
            % Bare version treated as exact match
            c.op = "==";
            c.version = p;
            constraints(end+1) = c; %#ok<AGROW>
        end
    end
end

function tf = tbx_satisfiesConstraint(ver, constraintStr)
%TBX_SATISFIESCONSTRAINT  Check if version satisfies a constraint string.
    arguments
        ver (1,1) string
        constraintStr (1,1) string
    end
    constraints = tbx_parseConstraint(constraintStr);
    tf = true;
    for i = 1:numel(constraints)
        c = constraints(i);
        if c.op == "*"
            continue;
        end
        cmp = tbx_compareVersions(ver, c.version);
        switch c.op
            case ">="
                if cmp < 0, tf = false; return; end
            case "<="
                if cmp > 0, tf = false; return; end
            case ">"
                if cmp <= 0, tf = false; return; end
            case "<"
                if cmp >= 0, tf = false; return; end
            case "=="
                if cmp ~= 0, tf = false; return; end
            case "!="
                if cmp == 0, tf = false; return; end
        end
    end
end

function tf = tbx_satisfiesMatlabConstraint(constraintStr)
%TBX_SATISFIESMATLABCONSTRAINT  Check if current MATLAB satisfies release constraint.
    arguments
        constraintStr (1,1) string
    end
    constraintStr = strip(constraintStr);
    if constraintStr == "" || constraintStr == "*"
        tf = true;
        return;
    end
    currentNum = tbx_matlabReleaseNum(tbx_matlabRelease());
    if startsWith(constraintStr, ">=")
        reqRel = strip(extractAfter(constraintStr, ">="));
        tf = currentNum >= tbx_matlabReleaseNum(reqRel);
    elseif startsWith(constraintStr, "<=")
        reqRel = strip(extractAfter(constraintStr, "<="));
        tf = currentNum <= tbx_matlabReleaseNum(reqRel);
    elseif startsWith(constraintStr, "==")
        reqRel = strip(extractAfter(constraintStr, "=="));
        tf = currentNum == tbx_matlabReleaseNum(reqRel);
    elseif startsWith(constraintStr, "<")
        reqRel = strip(extractAfter(constraintStr, "<"));
        tf = currentNum < tbx_matlabReleaseNum(reqRel);
    elseif startsWith(constraintStr, ">")
        reqRel = strip(extractAfter(constraintStr, ">"));
        tf = currentNum > tbx_matlabReleaseNum(reqRel);
    else
        % Bare release = exact match
        tf = currentNum == tbx_matlabReleaseNum(constraintStr);
    end
end

%% ========================================================================
%  Source management and index loading
%  ========================================================================

function sources = tbx_getSources()
%TBX_GETSOURCES  Return list of index source URLs.
    sourcesFile = fullfile(tbx_baseDir(), "state", "sources.json");
    if ~isfile(sourcesFile)
        sources = "https://kvasnica.github.io/tbxmanager-registry/index.json";
        return;
    end
    data = tbx_readJson(sourcesFile);
    if isfield(data, "sources")
        if iscell(data.sources)
            sources = string(data.sources);
        elseif ischar(data.sources) || isstring(data.sources)
            sources = string(data.sources);
        else
            sources = string(data.sources);
        end
    else
        sources = "https://kvasnica.github.io/tbxmanager-registry/index.json";
    end
    if isempty(sources)
        sources = string.empty;
    end
end

function tbx_writeSources(sources)
%TBX_WRITESOURCES  Write source list to sources.json.
    arguments
        sources string
    end
    sourcesFile = fullfile(tbx_baseDir(), "state", "sources.json");
    s.sources = cellstr(sources);
    tbx_writeJson(sourcesFile, s);
end

function index = tbx_loadIndex()
%TBX_LOADINDEX  Fetch and merge package indices from all sources.
    sources = tbx_getSources();
    index = struct();
    index.packages = struct();
    for i = 1:numel(sources)
        url = sources(i);
        try
            tbx_printf("Fetching index from %s ...\n", url);
            data = tbx_fetchJson(url);
            if isfield(data, "packages")
                pkgNames = fieldnames(data.packages);
                for j = 1:numel(pkgNames)
                    name = pkgNames{j};
                    index.packages.(name) = data.packages.(name);
                end
            end
        catch ME
            tbx_printWarning("Failed to fetch index from %s: %s", url, ME.message);
        end
    end
end

function tbx_addSource(url)
%TBX_ADDSOURCE  Add an index source URL.
    arguments
        url (1,1) string
    end
    sources = tbx_getSources();
    if any(sources == url)
        tbx_printf("Source already exists: %s\n", url);
        return;
    end
    sources(end+1) = url;
    tbx_writeSources(sources);
    tbx_printf("Added source: %s\n", url);
end

function tbx_removeSource(url)
%TBX_REMOVESOURCE  Remove an index source URL.
    arguments
        url (1,1) string
    end
    sources = tbx_getSources();
    mask = sources ~= url;
    if all(mask)
        tbx_printWarning("Source not found: %s", url);
        return;
    end
    sources = sources(mask);
    tbx_writeSources(sources);
    tbx_printf("Removed source: %s\n", url);
end

%% ========================================================================
%  Installation directory and installed package queries
%  ========================================================================

function d = tbx_installDir(pkgName, pkgVersion)
%TBX_INSTALLDIR  Return path for an installed package version.
    arguments
        pkgName (1,1) string
        pkgVersion (1,1) string
    end
    d = fullfile(tbx_baseDir(), "packages", pkgName, pkgVersion);
end

function pkgs = tbx_listInstalled()
%TBX_LISTINSTALLED  Return struct array of installed packages.
%   Each element has: name, version, meta (struct from meta.json)
    pkgsDir = fullfile(tbx_baseDir(), "packages");
    pkgs = struct("name", {}, "version", {}, "meta", {});
    if ~isfolder(pkgsDir)
        return;
    end
    listing = dir(pkgsDir);
    for i = 1:numel(listing)
        if listing(i).isdir && ~startsWith(listing(i).name, ".")
            pkgName = string(listing(i).name);
            pkgDir = fullfile(pkgsDir, pkgName);
            vListing = dir(pkgDir);
            for j = 1:numel(vListing)
                if vListing(j).isdir && ~startsWith(vListing(j).name, ".")
                    pkgVersion = string(vListing(j).name);
                    metaFile = fullfile(pkgDir, pkgVersion, "meta.json");
                    if isfile(metaFile)
                        meta = tbx_readJson(metaFile);
                    else
                        meta = struct("name", pkgName, "version", pkgVersion);
                    end
                    entry.name = pkgName;
                    entry.version = pkgVersion;
                    entry.meta = meta;
                    pkgs(end+1) = entry; %#ok<AGROW>
                end
            end
        end
    end
end

function [tf, installedVersion] = tbx_isInstalled(pkgName)
%TBX_ISINSTALLED  Check if a package is installed. Returns tf and version.
    arguments
        pkgName (1,1) string
    end
    pkgsDir = fullfile(tbx_baseDir(), "packages", pkgName);
    tf = false;
    installedVersion = "";
    if ~isfolder(pkgsDir)
        return;
    end
    listing = dir(pkgsDir);
    for i = 1:numel(listing)
        if listing(i).isdir && ~startsWith(listing(i).name, ".")
            tf = true;
            installedVersion = string(listing(i).name);
            return;
        end
    end
end

%% ========================================================================
%  Dependency resolver and topological sort
%  ========================================================================

function plan = tbx_resolve(requested, index)
%TBX_RESOLVE  Greedy dependency resolver with latest-version-first.
%   requested: struct array with fields name (string), constraint (string)
%   index: struct with .packages field
%   Returns plan: struct array with name, version, url, sha256, platform, dependencies
    arguments
        requested struct
        index struct
    end

    arch = tbx_platformArch();
    plan = struct("name", {}, "version", {}, "url", {}, "sha256", {}, ...
                  "platform", {}, "dependencies", {});
    resolved = containers.Map("KeyType", "char", "ValueType", "char");
    queue = requested(:)';
    visited = containers.Map("KeyType", "char", "ValueType", "logical");

    maxIter = 500;
    iter = 0;
    while ~isempty(queue) && iter < maxIter
        iter = iter + 1;
        item = queue(1);
        queue(1) = [];

        pkgName = string(item.name);
        constraint = string(item.constraint);

        % Already resolved?
        if resolved.isKey(char(pkgName))
            existingVer = string(resolved(char(pkgName)));
            if ~tbx_satisfiesConstraint(existingVer, constraint)
                error("TBXMANAGER:ConflictingDeps", ...
                    "Conflict: package '%s' resolved to %s but new constraint requires %s", ...
                    pkgName, existingVer, constraint);
            end
            continue;
        end

        if visited.isKey(char(pkgName))
            continue;
        end

        % Find package in index
        if ~isfield(index.packages, char(pkgName))
            error("TBXMANAGER:PackageNotFound", ...
                "Package '%s' not found in any index.", pkgName);
        end
        pkgInfo = index.packages.(char(pkgName));

        % Get all versions sorted descending
        if ~isfield(pkgInfo, "versions")
            error("TBXMANAGER:NoVersions", ...
                "Package '%s' has no versions available.", pkgName);
        end
        allVersions = string(fieldnames(pkgInfo.versions));
        allVersions = tbx_sortVersionsDesc(allVersions);

        % Find latest version satisfying constraint + platform + MATLAB
        foundVersion = "";
        foundUrl = "";
        foundSha = "";
        foundPlatform = "";
        foundDeps = struct();

        for vi = 1:numel(allVersions)
            v = allVersions(vi);
            if ~tbx_satisfiesConstraint(v, constraint)
                continue;
            end
            vInfo = tbx_getVersionField(pkgInfo.versions, v);

            % Check MATLAB version constraint
            if isfield(vInfo, "matlab") && ~isempty(vInfo.matlab)
                matlabConstraint = string(vInfo.matlab);
                if matlabConstraint ~= "" && ~tbx_satisfiesMatlabConstraint(matlabConstraint)
                    continue;
                end
            end

            % Check platform availability
            if isfield(vInfo, "platforms")
                [pUrl, pSha, pPlat] = tbx_resolvePlatform(vInfo.platforms, arch);
                if pUrl == ""
                    continue;
                end
                foundUrl = pUrl;
                foundSha = pSha;
                foundPlatform = pPlat;
            else
                if isfield(vInfo, "url")
                    foundUrl = string(vInfo.url);
                else
                    continue;
                end
                if isfield(vInfo, "sha256")
                    foundSha = string(vInfo.sha256);
                end
                foundPlatform = "all";
            end

            foundVersion = v;
            if isfield(vInfo, "dependencies") && isstruct(vInfo.dependencies)
                foundDeps = vInfo.dependencies;
            else
                foundDeps = struct();
            end
            break;
        end

        if foundVersion == ""
            error("TBXMANAGER:NoSatisfyingVersion", ...
                "No version of '%s' satisfies constraint '%s' for platform '%s'.", ...
                pkgName, constraint, arch);
        end

        resolved(char(pkgName)) = char(foundVersion);
        visited(char(pkgName)) = true;

        entry.name = pkgName;
        entry.version = foundVersion;
        entry.url = foundUrl;
        entry.sha256 = foundSha;
        entry.platform = foundPlatform;
        entry.dependencies = foundDeps;
        plan(end+1) = entry; %#ok<AGROW>

        % Enqueue dependencies
        if isstruct(foundDeps) && ~isempty(fieldnames(foundDeps))
            depNames = fieldnames(foundDeps);
            for di = 1:numel(depNames)
                depName = string(depNames{di});
                depConstraint = string(foundDeps.(depNames{di}));
                newItem.name = depName;
                newItem.constraint = depConstraint;
                queue(end+1) = newItem; %#ok<AGROW>
            end
        end
    end

    if iter >= maxIter
        error("TBXMANAGER:ResolverLoop", ...
            "Dependency resolver exceeded maximum iterations. Possible circular dependency.");
    end

    % Topological sort for install order
    plan = tbx_toposort(plan);
end

function vInfo = tbx_getVersionField(versions, versionStr)
%TBX_GETVERSIONFIELD  Access version info from the versions struct.
%   Handles JSON-decoded field names (e.g. "3.1.0" may become "x3_1_0").
    safeField = matlab.lang.makeValidName(char(versionStr));
    if isfield(versions, safeField)
        vInfo = versions.(safeField);
    elseif isfield(versions, char(versionStr))
        vInfo = versions.(char(versionStr));
    else
        fns = fieldnames(versions);
        for i = 1:numel(fns)
            if string(fns{i}) == string(safeField)
                vInfo = versions.(fns{i});
                return;
            end
        end
        error("TBXMANAGER:VersionFieldNotFound", ...
            "Cannot access version '%s' in index.", versionStr);
    end
end

function [url, sha, platform] = tbx_resolvePlatform(platforms, arch)
%TBX_RESOLVEPLATFORM  Pick best platform archive: exact match then "all".
    url = "";
    sha = "";
    platform = "";
    archField = matlab.lang.makeValidName(char(arch));
    % Try exact platform
    if isfield(platforms, char(arch))
        p = platforms.(char(arch));
        url = string(p.url);
        sha = string(p.sha256);
        platform = string(arch);
        return;
    elseif isfield(platforms, archField)
        p = platforms.(archField);
        url = string(p.url);
        sha = string(p.sha256);
        platform = string(arch);
        return;
    end
    % Fallback to "all"
    if isfield(platforms, "all")
        p = platforms.all;
        url = string(p.url);
        sha = string(p.sha256);
        platform = "all";
    end
end

function sorted = tbx_sortVersionsDesc(versions)
%TBX_SORTVERSIONSDESC  Sort version strings in descending order.
    arguments
        versions string
    end
    n = numel(versions);
    parsed = zeros(n, 3);
    for i = 1:n
        parsed(i,:) = tbx_parseVersion(versions(i));
    end
    [~, idx] = sortrows(parsed, [-1, -2, -3]);
    sorted = versions(idx);
end

function sorted = tbx_toposort(plan)
%TBX_TOPOSORT  Topological sort using Kahn's algorithm.
%   Dependencies are installed before their dependents.
    n = numel(plan);
    if n == 0
        sorted = plan;
        return;
    end

    % Build name-to-index map
    nameMap = containers.Map("KeyType", "char", "ValueType", "double");
    for i = 1:n
        nameMap(char(plan(i).name)) = i;
    end

    % Build in-degree and adjacency
    inDegree = zeros(1, n);
    adjList = cell(1, n);
    for i = 1:n
        adjList{i} = [];
    end
    for i = 1:n
        deps = plan(i).dependencies;
        if isstruct(deps) && ~isempty(fieldnames(deps))
            depNames = fieldnames(deps);
            for j = 1:numel(depNames)
                if nameMap.isKey(depNames{j})
                    depIdx = nameMap(depNames{j});
                    adjList{depIdx}(end+1) = i;
                    inDegree(i) = inDegree(i) + 1;
                end
            end
        end
    end

    % Kahn's algorithm
    queue = find(inDegree == 0);
    order = zeros(1, n);
    pos = 0;
    while ~isempty(queue)
        node = queue(1);
        queue(1) = [];
        pos = pos + 1;
        order(pos) = node;
        for k = 1:numel(adjList{node})
            neighbor = adjList{node}(k);
            inDegree(neighbor) = inDegree(neighbor) - 1;
            if inDegree(neighbor) == 0
                queue(end+1) = neighbor; %#ok<AGROW>
            end
        end
    end

    if pos < n
        error("TBXMANAGER:CyclicDependency", ...
            "Circular dependency detected in installation plan.");
    end

    sorted = plan(order);
end

%% ========================================================================
%  Enabled state and path management
%  ========================================================================

function enabled = tbx_loadEnabled()
%TBX_LOADENABLED  Load enabled packages state from enabled.json.
    enabledFile = fullfile(tbx_baseDir(), "state", "enabled.json");
    if isfile(enabledFile)
        data = tbx_readJson(enabledFile);
        if isfield(data, "packages")
            enabled = data.packages;
        else
            enabled = struct();
        end
    else
        enabled = struct();
    end
end

function tbx_writeEnabled(enabled)
%TBX_WRITEENABLED  Write enabled packages state to enabled.json.
    enabledFile = fullfile(tbx_baseDir(), "state", "enabled.json");
    data.packages = enabled;
    tbx_writeJson(enabledFile, data);
end

function tbx_addToPath(pkgName, pkgVersion)
%TBX_ADDTOPATH  Add package directory to MATLAB path and record as enabled.
    arguments
        pkgName (1,1) string
        pkgVersion (1,1) string
    end
    pkgDir = tbx_installDir(pkgName, pkgVersion);
    if ~isfolder(pkgDir)
        tbx_printWarning("Package directory not found: %s", pkgDir);
        return;
    end

    % Add the package dir and all subdirs (excluding ., +, @)
    pathDirs = tbx_getPathDirs(pkgDir);
    for i = 1:numel(pathDirs)
        addpath(pathDirs{i});
    end

    % Record in enabled.json
    enabled = tbx_loadEnabled();
    safeName = matlab.lang.makeValidName(char(pkgName));
    entry.version = char(pkgVersion);
    entry.path = char(pkgDir);
    enabled.(safeName) = entry;
    tbx_writeEnabled(enabled);
end

function tbx_removeFromPath(pkgName)
%TBX_REMOVEFROMPATH  Remove package from MATLAB path and enabled state.
    arguments
        pkgName (1,1) string
    end
    enabled = tbx_loadEnabled();
    safeName = matlab.lang.makeValidName(char(pkgName));
    if isfield(enabled, safeName)
        pkgDir = string(enabled.(safeName).path);
        if isfolder(pkgDir)
            pathDirs = tbx_getPathDirs(pkgDir);
            for i = 1:numel(pathDirs)
                try
                    rmpath(pathDirs{i});
                catch
                    % Ignore if not on path
                end
            end
        end
        enabled = rmfield(enabled, safeName);
        tbx_writeEnabled(enabled);
    end
end

function dirs = tbx_getPathDirs(rootDir)
%TBX_GETPATHDIRS  Get list of dirs to add to path for a package.
%   Recursively includes subdirectories, excluding hidden, + and @ dirs.
    arguments
        rootDir (1,1) string
    end
    dirs = {char(rootDir)};
    listing = dir(rootDir);
    for i = 1:numel(listing)
        if listing(i).isdir && ~startsWith(listing(i).name, '.') && ...
                ~startsWith(listing(i).name, '+') && ...
                ~startsWith(listing(i).name, '@')
            subDir = fullfile(rootDir, listing(i).name);
            subDirs = tbx_getPathDirs(subDir);
            dirs = [dirs, subDirs]; %#ok<AGROW>
        end
    end
end

%% ========================================================================
%  Lock file operations
%  ========================================================================

function lockData = tbx_readLock(lockFile)
%TBX_READLOCK  Read a tbxmanager.lock file.
    arguments
        lockFile (1,1) string
    end
    lockData = tbx_readJson(lockFile);
end

function tbx_writeLock(lockFile, lockData)
%TBX_WRITELOCK  Write a tbxmanager.lock file.
    arguments
        lockFile (1,1) string
        lockData struct
    end
    tbx_writeJson(lockFile, lockData);
end

function lockData = tbx_generateLock(projectFile)
%TBX_GENERATELOCK  Generate lock data from tbxmanager.json project file.
    arguments
        projectFile (1,1) string
    end
    if ~isfile(projectFile)
        error("TBXMANAGER:ProjectNotFound", ...
            "Project file not found: %s", projectFile);
    end

    project = tbx_readJson(projectFile);
    if ~isfield(project, "dependencies")
        error("TBXMANAGER:NoDependencies", ...
            "No 'dependencies' field in %s", projectFile);
    end

    % Build requested list
    depNames = fieldnames(project.dependencies);
    requested = struct("name", {}, "constraint", {});
    for i = 1:numel(depNames)
        req.name = string(depNames{i});
        req.constraint = string(project.dependencies.(depNames{i}));
        requested(end+1) = req; %#ok<AGROW>
    end

    % Load index and resolve
    index = tbx_loadIndex();
    plan = tbx_resolve(requested, index);

    % Build lock structure
    lockData.lockfile_version = 1;
    lockData.generated = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'", "TimeZone", "UTC"));
    lockData.requires = project.dependencies;
    lockPkgs = struct();
    for i = 1:numel(plan)
        p = plan(i);
        pkgEntry.version = char(p.version);
        pkgEntry.resolved.url = char(p.url);
        pkgEntry.resolved.sha256 = char(p.sha256);
        pkgEntry.resolved.platform = char(p.platform);
        if isstruct(p.dependencies) && ~isempty(fieldnames(p.dependencies))
            resolvedDeps = struct();
            dNames = fieldnames(p.dependencies);
            for j = 1:numel(dNames)
                dName = dNames{j};
                for k = 1:numel(plan)
                    if string(plan(k).name) == string(dName)
                        resolvedDeps.(dName) = char(plan(k).version);
                        break;
                    end
                end
            end
            pkgEntry.dependencies = resolvedDeps;
        else
            pkgEntry.dependencies = struct();
        end
        safeName = matlab.lang.makeValidName(char(p.name));
        lockPkgs.(safeName) = pkgEntry;
        clear pkgEntry;
    end
    lockData.packages = lockPkgs;
end

%% ========================================================================
%  Command: install
%  ========================================================================

function main_install(args)
%MAIN_INSTALL  Install packages with dependency resolution.
    if isempty(args)
        tbx_printError("Usage: tbxmanager install pkg1 [pkg2@>=1.0] ...");
        return;
    end

    % Parse package@constraint syntax
    requested = struct("name", {}, "constraint", {});
    for i = 1:numel(args)
        token = args(i);
        parts = split(token, "@");
        req.name = parts(1);
        if numel(parts) > 1
            req.constraint = strjoin(parts(2:end), "@");
        else
            req.constraint = "*";
        end
        requested(end+1) = req; %#ok<AGROW>
    end

    % Load index
    index = tbx_loadIndex();
    if isempty(fieldnames(index.packages))
        tbx_printError("No packages found in any index. Check sources with 'tbxmanager source list'.");
        return;
    end

    % Resolve dependencies
    tbx_printf("Resolving dependencies...\n");
    try
        plan = tbx_resolve(requested, index);
    catch ME
        tbx_printError("Dependency resolution failed: %s", ME.message);
        return;
    end

    if isempty(plan)
        tbx_printf("Nothing to install.\n");
        return;
    end

    % Filter out already-installed at correct version
    toInstall = struct("name", {}, "version", {}, "url", {}, "sha256", {}, ...
                       "platform", {}, "dependencies", {});
    for i = 1:numel(plan)
        [isInst, instVer] = tbx_isInstalled(plan(i).name);
        if isInst && instVer == plan(i).version
            tbx_printf("  %s@%s already installed.\n", plan(i).name, plan(i).version);
        else
            toInstall(end+1) = plan(i); %#ok<AGROW>
        end
    end

    if isempty(toInstall)
        tbx_printf("All packages are already installed.\n");
        return;
    end

    % Show plan
    tbx_printf("\nInstallation plan:\n");
    for i = 1:numel(toInstall)
        tbx_printf("  %s@%s (%s)\n", toInstall(i).name, toInstall(i).version, toInstall(i).platform);
    end
    tbx_printf("\n");

    % Confirm
    cfg = tbx_config();
    if isfield(cfg, "confirm_install") && cfg.confirm_install
        reply = input("Proceed? [Y/n]: ", "s");
        if ~isempty(reply) && ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
            tbx_printf("Installation cancelled.\n");
            return;
        end
    end

    % Execute installation
    cacheDir = fullfile(tbx_baseDir(), "cache");
    for i = 1:numel(toInstall)
        pkg = toInstall(i);
        tbx_printf("Installing %s@%s ...\n", pkg.name, pkg.version);
        tbx_installSinglePackage(pkg, cacheDir);
    end

    tbx_printf("\nDone. %d package(s) installed.\n", numel(toInstall));
end

function tbx_installSinglePackage(pkg, cacheDir)
%TBX_INSTALLSINGLEPACKAGE  Download, verify, extract, enable one package.
    % Download to cache
    [~, ~, urlExt] = fileparts(char(pkg.url));
    if isempty(urlExt)
        urlExt = ".zip";
    end
    cacheFile = fullfile(cacheDir, pkg.name + "-" + pkg.version + string(urlExt));
    if ~isfile(cacheFile)
        tbx_downloadFile(pkg.url, cacheFile);
    else
        tbx_printf("  Using cached download.\n");
    end

    % Verify SHA256
    if pkg.sha256 ~= "" && pkg.sha256 ~= "none"
        tbx_printf("  Verifying SHA256...\n");
        actualHash = tbx_sha256(cacheFile);
        if actualHash ~= pkg.sha256
            error("TBXMANAGER:HashMismatch", ...
                "SHA256 mismatch for %s@%s:\n  Expected: %s\n  Got:      %s", ...
                pkg.name, pkg.version, pkg.sha256, actualHash);
        end
    end

    % Remove old version if present
    [isInst, oldVer] = tbx_isInstalled(pkg.name);
    if isInst
        tbx_printf("  Removing old version %s...\n", oldVer);
        tbx_removeFromPath(pkg.name);
        oldDir = tbx_installDir(pkg.name, oldVer);
        if isfolder(oldDir)
            rmdir(char(oldDir), "s");
        end
    end

    % Extract to destination
    destDir = tbx_installDir(pkg.name, pkg.version);
    if ~isfolder(destDir)
        mkdir(char(destDir));
    end
    tbx_printf("  Extracting...\n");
    tmpDir = fullfile(tbx_baseDir(), "tmp", pkg.name + "-" + pkg.version);
    if isfolder(tmpDir)
        rmdir(char(tmpDir), "s");
    end
    mkdir(char(tmpDir));
    try
        unzip(char(cacheFile), char(tmpDir));
    catch ME
        error("TBXMANAGER:ExtractFailed", ...
            "Failed to extract %s: %s", cacheFile, ME.message);
    end

    % Flatten single top-level folder if present
    tmpContents = dir(tmpDir);
    tmpContents = tmpContents(~ismember({tmpContents.name}, {'.', '..'}));
    if numel(tmpContents) == 1 && tmpContents(1).isdir
        innerDir = fullfile(tmpDir, tmpContents(1).name);
        movefile(fullfile(char(innerDir), "*"), char(destDir));
        % Move hidden items
        hiddenItems = dir(fullfile(innerDir, ".*"));
        hiddenItems = hiddenItems(~ismember({hiddenItems.name}, {'.', '..'}));
        for h = 1:numel(hiddenItems)
            try
                movefile(fullfile(char(innerDir), hiddenItems(h).name), char(destDir));
            catch
            end
        end
    else
        movefile(fullfile(char(tmpDir), "*"), char(destDir));
    end
    if isfolder(tmpDir)
        rmdir(char(tmpDir), "s");
    end

    % Write meta.json
    meta.name = char(pkg.name);
    meta.version = char(pkg.version);
    meta.platform = char(pkg.platform);
    meta.sha256 = char(pkg.sha256);
    meta.url = char(pkg.url);
    meta.installed = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'", "TimeZone", "UTC"));
    if isstruct(pkg.dependencies) && ~isempty(fieldnames(pkg.dependencies))
        meta.dependencies = pkg.dependencies;
    else
        meta.dependencies = struct();
    end
    tbx_writeJson(fullfile(destDir, "meta.json"), meta);

    % Enable (add to path)
    cfg = tbx_config();
    if ~isfield(cfg, "auto_enable") || cfg.auto_enable
        tbx_addToPath(pkg.name, pkg.version);
        tbx_printf("  Enabled %s@%s.\n", pkg.name, pkg.version);
    end
end

%% ========================================================================
%  Command: uninstall
%  ========================================================================

function main_uninstall(args)
%MAIN_UNINSTALL  Uninstall packages, checking reverse dependencies.
    if isempty(args)
        tbx_printError("Usage: tbxmanager uninstall pkg1 [pkg2] ...");
        return;
    end

    installed = tbx_listInstalled();
    if isempty(installed)
        tbx_printf("No packages installed.\n");
        return;
    end
    installedNames = string({installed.name});

    for i = 1:numel(args)
        pkgName = args(i);
        if ~any(installedNames == pkgName)
            tbx_printWarning("Package '%s' is not installed.", pkgName);
            continue;
        end

        % Check reverse dependencies
        revDeps = tbx_findReverseDeps(pkgName, installed);
        revDeps = setdiff(revDeps, args);
        if ~isempty(revDeps)
            tbx_printWarning("Package '%s' is required by: %s", pkgName, strjoin(revDeps, ", "));
            reply = input(sprintf("  Remove '%s' anyway? [y/N]: ", pkgName), "s");
            if ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
                tbx_printf("  Skipping %s.\n", pkgName);
                continue;
            end
        end

        % Find installed version
        idx = find(installedNames == pkgName, 1);
        pkgVersion = installed(idx).version;

        % Remove from path
        tbx_removeFromPath(pkgName);

        % Delete files
        pkgDir = tbx_installDir(pkgName, pkgVersion);
        if isfolder(pkgDir)
            rmdir(char(pkgDir), "s");
        end
        % Remove parent dir if empty
        parentDir = fullfile(tbx_baseDir(), "packages", pkgName);
        if isfolder(parentDir)
            contents = dir(parentDir);
            contents = contents(~ismember({contents.name}, {'.', '..'}));
            if isempty(contents)
                rmdir(char(parentDir));
            end
        end

        tbx_printf("Uninstalled %s@%s.\n", pkgName, pkgVersion);
    end
end

function revDeps = tbx_findReverseDeps(pkgName, installed)
%TBX_FINDREVERSEDEPS  Find installed packages that depend on pkgName.
    revDeps = string.empty;
    for i = 1:numel(installed)
        meta = installed(i).meta;
        if isfield(meta, "dependencies") && isstruct(meta.dependencies)
            depNames = fieldnames(meta.dependencies);
            for j = 1:numel(depNames)
                if string(depNames{j}) == pkgName
                    revDeps(end+1) = installed(i).name; %#ok<AGROW>
                end
            end
        end
    end
end

%% ========================================================================
%  Command: update
%  ========================================================================

function main_update(args)
%MAIN_UPDATE  Update installed packages. If no args, update all.
    installed = tbx_listInstalled();
    if isempty(installed)
        tbx_printf("No packages installed.\n");
        return;
    end

    % Load index
    index = tbx_loadIndex();
    if isempty(fieldnames(index.packages))
        tbx_printError("No packages found in any index.");
        return;
    end

    % Determine which packages to check
    if isempty(args)
        pkgsToCheck = string({installed.name});
    else
        pkgsToCheck = args;
    end

    % Find packages with available updates
    updatable = struct("name", {}, "constraint", {});
    for i = 1:numel(pkgsToCheck)
        pkgName = pkgsToCheck(i);
        [isInst, currentVer] = tbx_isInstalled(pkgName);
        if ~isInst
            tbx_printWarning("Package '%s' is not installed.", pkgName);
            continue;
        end
        if ~isfield(index.packages, char(pkgName))
            tbx_printWarning("Package '%s' not found in index.", pkgName);
            continue;
        end
        pkgInfo = index.packages.(char(pkgName));
        latestVer = "";
        if isfield(pkgInfo, "latest")
            latestVer = string(pkgInfo.latest);
        end
        if latestVer ~= "" && tbx_compareVersions(latestVer, currentVer) > 0
            tbx_printf("  %s: %s -> %s\n", pkgName, currentVer, latestVer);
            req.name = pkgName;
            req.constraint = ">=" + latestVer;
            updatable(end+1) = req; %#ok<AGROW>
        else
            tbx_printf("  %s: %s (up to date)\n", pkgName, currentVer);
        end
    end

    if isempty(updatable)
        tbx_printf("All packages are up to date.\n");
        return;
    end

    % Resolve and install
    tbx_printf("\nResolving dependencies for updates...\n");
    try
        plan = tbx_resolve(updatable, index);
    catch ME
        tbx_printError("Dependency resolution failed: %s", ME.message);
        return;
    end

    % Show plan
    tbx_printf("\nUpdate plan:\n");
    for i = 1:numel(plan)
        [isInst, oldVer] = tbx_isInstalled(plan(i).name);
        if isInst && oldVer ~= plan(i).version
            tbx_printf("  %s: %s -> %s\n", plan(i).name, oldVer, plan(i).version);
        elseif ~isInst
            tbx_printf("  %s: (new) %s\n", plan(i).name, plan(i).version);
        else
            tbx_printf("  %s: %s (no change)\n", plan(i).name, plan(i).version);
        end
    end
    tbx_printf("\n");

    reply = input("Proceed? [Y/n]: ", "s");
    if ~isempty(reply) && ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
        tbx_printf("Update cancelled.\n");
        return;
    end

    % Execute updates
    cacheDir = fullfile(tbx_baseDir(), "cache");
    updated = 0;
    for i = 1:numel(plan)
        pkg = plan(i);
        [isInst, oldVer] = tbx_isInstalled(pkg.name);
        if isInst && oldVer == pkg.version
            continue;
        end
        tbx_printf("Updating %s to %s ...\n", pkg.name, pkg.version);
        tbx_installSinglePackage(pkg, cacheDir);
        updated = updated + 1;
    end

    tbx_printf("\nDone. %d package(s) updated.\n", updated);
end

%% ========================================================================
%  Command: list
%  ========================================================================

function main_list(~)
%MAIN_LIST  Display table of installed packages.
    installed = tbx_listInstalled();
    if isempty(installed)
        tbx_printf("No packages installed.\n");
        return;
    end

    enabled = tbx_loadEnabled();

    % Try to get latest versions from index (best effort)
    latestVersions = containers.Map("KeyType", "char", "ValueType", "char");
    try
        index = tbx_loadIndex();
        if isfield(index, "packages")
            pkgNames = fieldnames(index.packages);
            for i = 1:numel(pkgNames)
                name = pkgNames{i};
                if isfield(index.packages.(name), "latest")
                    latestVersions(name) = char(string(index.packages.(name).latest));
                end
            end
        end
    catch
        % Silently ignore if index unavailable
    end

    % Build table data
    names = cell(numel(installed), 1);
    versions = cell(numel(installed), 1);
    latests = cell(numel(installed), 1);
    statuses = cell(numel(installed), 1);

    for i = 1:numel(installed)
        pkg = installed(i);
        names{i} = char(pkg.name);
        versions{i} = char(pkg.version);

        if latestVersions.isKey(char(pkg.name))
            latests{i} = latestVersions(char(pkg.name));
        else
            latests{i} = "-";
        end

        safeName = matlab.lang.makeValidName(char(pkg.name));
        if isfield(enabled, safeName)
            statuses{i} = "enabled";
        else
            statuses{i} = "disabled";
        end
    end

    tbx_printTable({"Name", "Version", "Latest", "Status"}, ...
                   {names, versions, latests, statuses});
end

%% ========================================================================
%  Command: search
%  ========================================================================

function main_search(args)
%MAIN_SEARCH  Search available packages by name or description.
    if isempty(args)
        tbx_printError("Usage: tbxmanager search <query>");
        return;
    end
    query = lower(strjoin(args, " "));

    index = tbx_loadIndex();
    if isempty(fieldnames(index.packages))
        tbx_printf("No packages found in any index.\n");
        return;
    end

    pkgNames = fieldnames(index.packages);
    matchNames = {};
    matchDescs = {};
    matchVers = {};

    for i = 1:numel(pkgNames)
        name = pkgNames{i};
        pkgInfo = index.packages.(name);
        desc = "";
        if isfield(pkgInfo, "description")
            desc = string(pkgInfo.description);
        end
        if contains(lower(string(name)), query) || contains(lower(desc), query)
            matchNames{end+1} = name; %#ok<AGROW>
            matchDescs{end+1} = char(desc); %#ok<AGROW>
            if isfield(pkgInfo, "latest")
                matchVers{end+1} = char(string(pkgInfo.latest)); %#ok<AGROW>
            else
                matchVers{end+1} = "-"; %#ok<AGROW>
            end
        end
    end

    if isempty(matchNames)
        tbx_printf("No packages matching '%s'.\n", query);
        return;
    end

    tbx_printf("Found %d package(s):\n\n", numel(matchNames));
    tbx_printTable({"Name", "Latest", "Description"}, ...
                   {matchNames', matchVers', matchDescs'});
end

%% ========================================================================
%  Command: info
%  ========================================================================

function main_info(args)
%MAIN_INFO  Show detailed information about a package.
    if isempty(args)
        tbx_printError("Usage: tbxmanager info <package>");
        return;
    end
    pkgName = args(1);

    index = tbx_loadIndex();
    if ~isfield(index.packages, char(pkgName))
        tbx_printError("Package '%s' not found in any index.", pkgName);
        return;
    end

    pkg = index.packages.(char(pkgName));

    tbx_printf("Package: %s\n", pkgName);
    if isfield(pkg, "description")
        tbx_printf("Description: %s\n", string(pkg.description));
    end
    if isfield(pkg, "homepage")
        tbx_printf("Homepage: %s\n", string(pkg.homepage));
    end
    if isfield(pkg, "license")
        tbx_printf("License: %s\n", string(pkg.license));
    end
    if isfield(pkg, "authors")
        authors = pkg.authors;
        if iscell(authors)
            tbx_printf("Authors: %s\n", strjoin(string(authors), ", "));
        else
            tbx_printf("Authors: %s\n", string(authors));
        end
    end
    if isfield(pkg, "latest")
        tbx_printf("Latest version: %s\n", string(pkg.latest));
    end

    [isInst, instVer] = tbx_isInstalled(pkgName);
    if isInst
        tbx_printf("Installed version: %s\n", instVer);
    else
        tbx_printf("Not installed.\n");
    end

    if isfield(pkg, "versions")
        tbx_printf("\nAvailable versions:\n");
        verNames = string(fieldnames(pkg.versions));
        verNames = tbx_sortVersionsDesc(verNames);
        for i = 1:numel(verNames)
            v = verNames(i);
            vInfo = tbx_getVersionField(pkg.versions, v);
            extra = "";
            if isfield(vInfo, "released")
                extra = extra + " (released: " + string(vInfo.released) + ")";
            end
            if isfield(vInfo, "matlab") && ~isempty(vInfo.matlab)
                extra = extra + " [matlab: " + string(vInfo.matlab) + "]";
            end
            tbx_printf("  %s%s\n", v, extra);

            if isfield(vInfo, "dependencies") && isstruct(vInfo.dependencies) && ~isempty(fieldnames(vInfo.dependencies))
                depNames = fieldnames(vInfo.dependencies);
                for j = 1:numel(depNames)
                    tbx_printf("    requires: %s %s\n", string(depNames{j}), string(vInfo.dependencies.(depNames{j})));
                end
            end

            if isfield(vInfo, "platforms") && isstruct(vInfo.platforms)
                platNames = fieldnames(vInfo.platforms);
                tbx_printf("    platforms: %s\n", strjoin(string(platNames), ", "));
            end
        end
    end
end

%% ========================================================================
%  Command: lock
%  ========================================================================

function main_lock(~)
%MAIN_LOCK  Generate tbxmanager.lock from tbxmanager.json in CWD.
    projectFile = fullfile(pwd, "tbxmanager.json");
    lockFile = fullfile(pwd, "tbxmanager.lock");

    if ~isfile(projectFile)
        tbx_printError("No tbxmanager.json in current directory. Run 'tbxmanager init' first.");
        return;
    end

    tbx_printf("Generating lock file from %s ...\n", projectFile);
    try
        lockData = tbx_generateLock(projectFile);
        tbx_writeLock(lockFile, lockData);
        tbx_printf("Lock file written to %s\n", lockFile);

        if isfield(lockData, "packages")
            pkgNames = fieldnames(lockData.packages);
            tbx_printf("\nResolved packages:\n");
            for i = 1:numel(pkgNames)
                name = pkgNames{i};
                ver = lockData.packages.(name).version;
                tbx_printf("  %s@%s\n", name, ver);
            end
        end
    catch ME
        tbx_printError("Lock generation failed: %s", ME.message);
    end
end

%% ========================================================================
%  Command: sync
%  ========================================================================

function main_sync(~)
%MAIN_SYNC  Install packages from tbxmanager.lock in CWD.
    lockFile = fullfile(pwd, "tbxmanager.lock");
    if ~isfile(lockFile)
        tbx_printError("No tbxmanager.lock in current directory. Run 'tbxmanager lock' first.");
        return;
    end

    tbx_printf("Syncing from %s ...\n", lockFile);
    lockData = tbx_readLock(lockFile);

    if ~isfield(lockData, "packages")
        tbx_printf("No packages in lock file.\n");
        return;
    end

    pkgNames = fieldnames(lockData.packages);
    installed = tbx_listInstalled();
    installedMap = containers.Map("KeyType", "char", "ValueType", "char");
    for i = 1:numel(installed)
        installedMap(char(installed(i).name)) = char(installed(i).version);
    end

    toInstall = {};
    toRemove = {};

    % Find packages to install/update
    for i = 1:numel(pkgNames)
        name = pkgNames{i};
        lockPkg = lockData.packages.(name);
        reqVer = string(lockPkg.version);
        if installedMap.isKey(name)
            instVer = string(installedMap(name));
            if instVer ~= reqVer
                toInstall{end+1} = name; %#ok<AGROW>
            end
        else
            toInstall{end+1} = name; %#ok<AGROW>
        end
    end

    % Find packages to remove (installed but not in lock)
    lockSet = string(pkgNames);
    for i = 1:numel(installed)
        if ~any(lockSet == installed(i).name)
            toRemove{end+1} = char(installed(i).name); %#ok<AGROW>
        end
    end

    if isempty(toInstall) && isempty(toRemove)
        tbx_printf("Everything is up to date.\n");
        return;
    end

    if ~isempty(toInstall)
        tbx_printf("\nPackages to install/update:\n");
        for i = 1:numel(toInstall)
            name = toInstall{i};
            ver = lockData.packages.(name).version;
            tbx_printf("  %s@%s\n", name, ver);
        end
    end
    if ~isempty(toRemove)
        tbx_printf("\nPackages to remove (not in lock file):\n");
        for i = 1:numel(toRemove)
            tbx_printf("  %s\n", toRemove{i});
        end
    end

    tbx_printf("\n");
    reply = input("Proceed? [Y/n]: ", "s");
    if ~isempty(reply) && ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
        tbx_printf("Sync cancelled.\n");
        return;
    end

    % Remove extra packages
    for i = 1:numel(toRemove)
        pkgNameStr = string(toRemove{i});
        [~, pkgVer] = tbx_isInstalled(pkgNameStr);
        tbx_removeFromPath(pkgNameStr);
        pkgDir = tbx_installDir(pkgNameStr, pkgVer);
        if isfolder(pkgDir)
            rmdir(char(pkgDir), "s");
        end
        parentDir = fullfile(tbx_baseDir(), "packages", pkgNameStr);
        if isfolder(parentDir)
            contents = dir(parentDir);
            contents = contents(~ismember({contents.name}, {'.', '..'}));
            if isempty(contents)
                rmdir(char(parentDir));
            end
        end
        tbx_printf("Removed %s.\n", pkgNameStr);
    end

    % Install/update packages from lock
    cacheDir = fullfile(tbx_baseDir(), "cache");
    for i = 1:numel(toInstall)
        name = toInstall{i};
        lockPkg = lockData.packages.(name);
        pkgVer = string(lockPkg.version);
        pkgUrl = string(lockPkg.resolved.url);
        pkgSha = string(lockPkg.resolved.sha256);
        pkgPlatform = "all";
        if isfield(lockPkg.resolved, "platform")
            pkgPlatform = string(lockPkg.resolved.platform);
        end

        tbx_printf("Installing %s@%s ...\n", name, pkgVer);

        pkg.name = string(name);
        pkg.version = pkgVer;
        pkg.url = pkgUrl;
        pkg.sha256 = pkgSha;
        pkg.platform = pkgPlatform;
        if isfield(lockPkg, "dependencies")
            pkg.dependencies = lockPkg.dependencies;
        else
            pkg.dependencies = struct();
        end

        tbx_installSinglePackage(pkg, cacheDir);
    end

    tbx_printf("\nSync complete.\n");
end

%% ========================================================================
%  Command: init
%  ========================================================================

function main_init(~)
%MAIN_INIT  Create a tbxmanager.json template in the current directory.
    projectFile = fullfile(pwd, "tbxmanager.json");
    if isfile(projectFile)
        tbx_printWarning("tbxmanager.json already exists in current directory.");
        reply = input("Overwrite? [y/N]: ", "s");
        if ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
            tbx_printf("Cancelled.\n");
            return;
        end
    end

    [~, dirName] = fileparts(pwd);
    project.name = char(dirName);
    project.matlab = char(">=" + tbx_matlabRelease());
    project.dependencies = struct();

    tbx_writeJson(projectFile, project);
    tbx_printf("Created %s\n", projectFile);
    tbx_printf("Edit the file to add dependencies, then run 'tbxmanager lock'.\n");
end

%% ========================================================================
%  Command: selfupdate
%  ========================================================================

function main_selfupdate(~)
%MAIN_SELFUPDATE  Update tbxmanager.m itself.
    cfg = tbx_config();
    if isfield(cfg, "selfupdate_url")
        url = string(cfg.selfupdate_url);
    else
        url = "https://tbxmanager.com/tbxmanager.m";
    end

    tbx_printf("Checking for updates from %s ...\n", url);

    tmpFile = fullfile(tbx_baseDir(), "tmp", "tbxmanager_new.m");
    try
        tbx_downloadFile(url, tmpFile);
    catch ME
        tbx_printError("Failed to download update: %s", ME.message);
        return;
    end

    currentFile = string(which("tbxmanager"));
    if currentFile == ""
        tbx_printError("Cannot determine location of current tbxmanager.m");
        if isfile(tmpFile)
            delete(tmpFile);
        end
        return;
    end

    % Compare SHA256
    currentHash = tbx_sha256(currentFile);
    newHash = tbx_sha256(tmpFile);

    if currentHash == newHash
        tbx_printf("tbxmanager is already up to date.\n");
        delete(tmpFile);
        return;
    end

    tbx_printf("Updating tbxmanager.m ...\n");
    tbx_printf("  Current: %s\n", currentHash);
    tbx_printf("  New:     %s\n", newHash);
    try
        copyfile(char(tmpFile), char(currentFile), "f");
        delete(tmpFile);
        tbx_printf("Updated successfully.\n");
        tbx_printf("Run 'rehash' or restart MATLAB to use the new version.\n");
        rehash;
    catch ME
        tbx_printError("Failed to replace tbxmanager.m: %s", ME.message);
        tbx_printf("  You can manually copy from: %s\n", tmpFile);
    end
end

%% ========================================================================
%  Command: source
%  ========================================================================

function main_source(args)
%MAIN_SOURCE  Manage index sources: add, remove, list.
    if isempty(args)
        args = "list";
    end
    subCmd = lower(args(1));

    switch subCmd
        case "add"
            if numel(args) < 2
                tbx_printError("Usage: tbxmanager source add <url>");
                return;
            end
            tbx_addSource(args(2));

        case "remove"
            if numel(args) < 2
                tbx_printError("Usage: tbxmanager source remove <url>");
                return;
            end
            tbx_removeSource(args(2));

        case "list"
            sources = tbx_getSources();
            if isempty(sources)
                tbx_printf("No sources configured.\n");
            else
                tbx_printf("Configured sources:\n");
                for i = 1:numel(sources)
                    tbx_printf("  %d. %s\n", i, sources(i));
                end
            end

        otherwise
            tbx_printError("Unknown source sub-command '%s'. Use add, remove, or list.", subCmd);
    end
end

%% ========================================================================
%  Command: enable
%  ========================================================================

function main_enable(args)
%MAIN_ENABLE  Add installed packages to the MATLAB path.
    if isempty(args)
        tbx_printError("Usage: tbxmanager enable pkg1 [pkg2] ...");
        return;
    end
    for i = 1:numel(args)
        pkgName = args(i);
        [isInst, pkgVer] = tbx_isInstalled(pkgName);
        if ~isInst
            tbx_printWarning("Package '%s' is not installed.", pkgName);
            continue;
        end
        tbx_addToPath(pkgName, pkgVer);
        tbx_printf("Enabled %s@%s.\n", pkgName, pkgVer);
    end
end

%% ========================================================================
%  Command: disable
%  ========================================================================

function main_disable(args)
%MAIN_DISABLE  Remove packages from the MATLAB path.
    if isempty(args)
        tbx_printError("Usage: tbxmanager disable pkg1 [pkg2] ...");
        return;
    end
    for i = 1:numel(args)
        pkgName = args(i);
        tbx_removeFromPath(pkgName);
        tbx_printf("Disabled %s.\n", pkgName);
    end
end

%% ========================================================================
%  Command: restorepath
%  ========================================================================

function main_restorepath(~)
%MAIN_RESTOREPATH  Restore paths for all enabled packages (for startup.m).
    enabled = tbx_loadEnabled();
    if isempty(fieldnames(enabled))
        return;
    end

    fns = fieldnames(enabled);
    count = 0;
    for i = 1:numel(fns)
        entry = enabled.(fns{i});
        pkgPath = string(entry.path);
        pkgVer = string(entry.version);
        if isfolder(pkgPath)
            pathDirs = tbx_getPathDirs(pkgPath);
            for j = 1:numel(pathDirs)
                addpath(pathDirs{j});
            end
            count = count + 1;
        else
            tbx_printWarning("Path not found for '%s' (%s): %s", fns{i}, pkgVer, pkgPath);
        end
    end
    if count > 0
        tbx_printf("Restored paths for %d package(s).\n", count);
    end
end

%% ========================================================================
%  Command: require
%  ========================================================================

function main_require(args)
%MAIN_REQUIRE  Assert that specified packages are enabled. Error if not.
    if isempty(args)
        tbx_printError("Usage: tbxmanager require pkg1 [pkg2@>=1.0] ...");
        return;
    end

    enabled = tbx_loadEnabled();
    missing = string.empty;

    for i = 1:numel(args)
        token = args(i);
        parts = split(token, "@");
        pkgName = parts(1);
        constraint = "*";
        if numel(parts) > 1
            constraint = strjoin(parts(2:end), "@");
        end

        safeName = matlab.lang.makeValidName(char(pkgName));
        if ~isfield(enabled, safeName)
            missing(end+1) = pkgName; %#ok<AGROW>
        elseif constraint ~= "*"
            enabledVer = string(enabled.(safeName).version);
            if ~tbx_satisfiesConstraint(enabledVer, constraint)
                error("TBXMANAGER:RequireVersionMismatch", ...
                    "Package '%s' is enabled at version %s but requires %s.", ...
                    pkgName, enabledVer, constraint);
            end
        end
    end

    if ~isempty(missing)
        error("TBXMANAGER:RequireMissing", ...
            "Required packages not enabled: %s\nRun: tbxmanager install %s", ...
            strjoin(missing, ", "), strjoin(missing, " "));
    end
end

%% ========================================================================
%  Command: cache
%  ========================================================================

function main_cache(args)
%MAIN_CACHE  Cache management: clean or list.
    if isempty(args)
        args = "list";
    end
    subCmd = lower(args(1));
    cacheDir = fullfile(tbx_baseDir(), "cache");

    switch subCmd
        case "clean"
            if isfolder(cacheDir)
                listing = dir(cacheDir);
                listing = listing(~ismember({listing.name}, {'.', '..'}));
                totalSize = 0;
                for i = 1:numel(listing)
                    totalSize = totalSize + listing(i).bytes;
                    delete(fullfile(cacheDir, listing(i).name));
                end
                tbx_printf("Cleaned cache: removed %d file(s), freed %s.\n", ...
                    numel(listing), tbx_formatBytes(totalSize));
            else
                tbx_printf("Cache directory does not exist.\n");
            end

        case "list"
            if ~isfolder(cacheDir)
                tbx_printf("Cache is empty.\n");
                return;
            end
            listing = dir(cacheDir);
            listing = listing(~ismember({listing.name}, {'.', '..'}));
            if isempty(listing)
                tbx_printf("Cache is empty.\n");
                return;
            end
            totalSize = 0;
            tbx_printf("Cached files:\n");
            for i = 1:numel(listing)
                sz = listing(i).bytes;
                totalSize = totalSize + sz;
                tbx_printf("  %s (%s)\n", listing(i).name, tbx_formatBytes(sz));
            end
            tbx_printf("\nTotal: %d file(s), %s\n", numel(listing), tbx_formatBytes(totalSize));

        otherwise
            tbx_printError("Unknown cache sub-command '%s'. Use clean or list.", subCmd);
    end
end

%% ========================================================================
%  Command: help
%  ========================================================================

function main_help(args)
%MAIN_HELP  Display help text.
    if ~isempty(args)
        cmd = lower(args(1));
    else
        cmd = "";
    end

    switch cmd
        case "install"
            tbx_printf("tbxmanager install - Install packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager install pkg1 [pkg2@>=1.0] ...\n\n");
            tbx_printf("Install one or more packages with automatic dependency resolution.\n");
            tbx_printf("Version constraints can be appended with @:\n");
            tbx_printf("  pkg@>=1.0        Minimum version\n");
            tbx_printf("  pkg@<2.0         Upper bound\n");
            tbx_printf("  pkg@==1.2.3      Exact version\n");
            tbx_printf("  pkg@~=1.2        Compatible release (>=1.2, <2.0)\n");
            tbx_printf("  pkg@>=1.0,<2.0   Range (comma = AND)\n");

        case "uninstall"
            tbx_printf("tbxmanager uninstall - Remove packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager uninstall pkg1 [pkg2] ...\n\n");
            tbx_printf("Remove installed packages. Warns if other packages depend on them.\n");

        case "update"
            tbx_printf("tbxmanager update - Update packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager update           Update all packages\n");
            tbx_printf("  tbxmanager update pkg1 ...  Update specific packages\n");

        case "list"
            tbx_printf("tbxmanager list - List installed packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager list\n\n");
            tbx_printf("Shows a table of installed packages with version and status.\n");

        case "search"
            tbx_printf("tbxmanager search - Search available packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager search <query>\n\n");
            tbx_printf("Search package names and descriptions by substring match.\n");

        case "info"
            tbx_printf("tbxmanager info - Show package details\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager info <package>\n\n");
            tbx_printf("Show all metadata, versions, dependencies, and platforms.\n");

        case "lock"
            tbx_printf("tbxmanager lock - Generate lock file\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager lock\n\n");
            tbx_printf("Reads tbxmanager.json, resolves all dependencies for the current\n");
            tbx_printf("platform, and writes tbxmanager.lock with pinned versions.\n");

        case "sync"
            tbx_printf("tbxmanager sync - Install from lock file\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager sync\n\n");
            tbx_printf("Install exact versions from tbxmanager.lock.\n");
            tbx_printf("Removes packages not listed in the lock file.\n");

        case "init"
            tbx_printf("tbxmanager init - Create project file\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager init\n\n");
            tbx_printf("Create a tbxmanager.json template in the current directory.\n");

        case "selfupdate"
            tbx_printf("tbxmanager selfupdate - Update tbxmanager itself\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager selfupdate\n\n");
            tbx_printf("Download the latest tbxmanager.m and replace the current one.\n");

        case "source"
            tbx_printf("tbxmanager source - Manage index sources\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager source list          List configured sources\n");
            tbx_printf("  tbxmanager source add <url>     Add an index source\n");
            tbx_printf("  tbxmanager source remove <url>  Remove an index source\n");

        case "enable"
            tbx_printf("tbxmanager enable - Add packages to MATLAB path\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager enable pkg1 [pkg2] ...\n\n");
            tbx_printf("Enable installed packages by adding them to the MATLAB path.\n");

        case "disable"
            tbx_printf("tbxmanager disable - Remove packages from MATLAB path\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager disable pkg1 [pkg2] ...\n\n");
            tbx_printf("Disable packages by removing them from the MATLAB path.\n");

        case "restorepath"
            tbx_printf("tbxmanager restorepath - Restore paths for enabled packages\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager restorepath\n\n");
            tbx_printf("Re-add all enabled packages to the MATLAB path.\n");
            tbx_printf("Add this to your startup.m for automatic path restoration.\n");

        case "require"
            tbx_printf("tbxmanager require - Assert packages are enabled\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager require pkg1 [pkg2@>=1.0] ...\n\n");
            tbx_printf("Throws an error if any listed package is not enabled\n");
            tbx_printf("or does not satisfy the given version constraint.\n");

        case "cache"
            tbx_printf("tbxmanager cache - Manage download cache\n\n");
            tbx_printf("Usage:\n");
            tbx_printf("  tbxmanager cache list    Show cached files\n");
            tbx_printf("  tbxmanager cache clean   Remove all cached files\n");

        otherwise
            tbx_printf("tbxmanager v2.0 - MATLAB Package Manager\n\n");
            tbx_printf("Usage: tbxmanager <command> [arguments]\n\n");
            tbx_printf("Package commands:\n");
            tbx_printf("  install       Install packages with dependency resolution\n");
            tbx_printf("  uninstall     Remove installed packages\n");
            tbx_printf("  update        Update packages to latest versions\n");
            tbx_printf("  list          Show installed packages\n");
            tbx_printf("  search        Search available packages\n");
            tbx_printf("  info          Show package details\n");
            tbx_printf("\nProject commands:\n");
            tbx_printf("  init          Create tbxmanager.json template\n");
            tbx_printf("  lock          Generate tbxmanager.lock from tbxmanager.json\n");
            tbx_printf("  sync          Install from tbxmanager.lock\n");
            tbx_printf("\nPath commands:\n");
            tbx_printf("  enable        Add packages to MATLAB path\n");
            tbx_printf("  disable       Remove packages from MATLAB path\n");
            tbx_printf("  restorepath   Restore paths for enabled packages\n");
            tbx_printf("  require       Assert packages are enabled\n");
            tbx_printf("\nMaintenance commands:\n");
            tbx_printf("  selfupdate    Update tbxmanager itself\n");
            tbx_printf("  source        Manage index sources (add/remove/list)\n");
            tbx_printf("  cache         Manage download cache (clean/list)\n");
            tbx_printf("  help          Show this help or help for a command\n");
            tbx_printf("\nExamples:\n");
            tbx_printf("  tbxmanager install mpt\n");
            tbx_printf("  tbxmanager install mpt@>=3.0 cddmex\n");
            tbx_printf("  tbxmanager update\n");
            tbx_printf("  tbxmanager search parametric\n");
            tbx_printf("  tbxmanager help install\n");
            tbx_printf("\nStorage: %s\n", tbx_baseDir());
    end
end

function main_internal(args)
%MAIN_INTERNAL  Expose internal functions for testing. Not for end users.
%   tbxmanager internal__ <function_name> <args...>
%   Returns result via assignin('base', 'ans', result)
    if isempty(args)
        error("TBXMANAGER:Internal", "Usage: tbxmanager internal__ <func> <args...>");
    end
    funcName = args(1);
    funcArgs = args(2:end);
    switch funcName
        case "parseVersion"
            result = tbx_parseVersion(funcArgs(1));
        case "compareVersions"
            result = tbx_compareVersions(funcArgs(1), funcArgs(2));
        case "satisfiesConstraint"
            result = tbx_satisfiesConstraint(funcArgs(1), funcArgs(2));
        case "parseConstraint"
            result = tbx_parseConstraint(funcArgs(1));
        case "matlabReleaseNum"
            result = tbx_matlabReleaseNum(funcArgs(1));
        case "sha256"
            result = tbx_sha256(funcArgs(1));
        case "baseDir"
            result = tbx_baseDir();
        case "platformArch"
            result = tbx_platformArch();
        case "loadIndex"
            result = tbx_loadIndex();
        case "resolve"
            index = tbx_loadIndex();
            requested = struct("name", {}, "constraint", {});
            for i = 1:numel(funcArgs)
                parts = split(funcArgs(i), "@");
                r.name = parts(1);
                if numel(parts) > 1
                    r.constraint = parts(2);
                else
                    r.constraint = "*";
                end
                requested(end+1) = r; %#ok<AGROW>
            end
            result = tbx_resolve(requested, index);
        case "listInstalled"
            result = tbx_listInstalled();
        case "loadEnabled"
            result = tbx_loadEnabled();
        case "readJson"
            result = tbx_readJson(funcArgs(1));
        case "writeJson"
            tbx_writeJson(funcArgs(1), jsondecode(strjoin(funcArgs(2:end))));
            result = true;
        case "toposort"
            % Expects a JSON string describing the plan struct array
            result = tbx_toposort(jsondecode(funcArgs(1)));
        otherwise
            error("TBXMANAGER:Internal", "Unknown internal function: %s", funcName);
    end
    assignin("base", "ans", result);
end

%% ========================================================================
%  Printing utilities
%  ========================================================================

function tbx_printf(fmt, varargin)
%TBX_PRINTF  Print formatted message to console.
    fprintf(fmt, varargin{:});
end

function tbx_printTable(headers, columns)
%TBX_PRINTTABLE  Print a formatted table to console.
%   headers: cell array of header strings
%   columns: cell array of cell arrays (one per column)
    nCols = numel(headers);
    nRows = numel(columns{1});

    % Calculate column widths
    widths = zeros(1, nCols);
    for c = 1:nCols
        widths(c) = strlength(string(headers{c}));
        for r = 1:nRows
            val = string(columns{c}{r});
            widths(c) = max(widths(c), strlength(val));
        end
        widths(c) = widths(c) + 2;
    end

    % Print header
    headerLine = "";
    separatorLine = "";
    for c = 1:nCols
        headerLine = headerLine + pad(string(headers{c}), widths(c));
        separatorLine = separatorLine + string(repmat('-', 1, widths(c)));
    end
    tbx_printf("%s\n", headerLine);
    tbx_printf("%s\n", separatorLine);

    % Print rows
    for r = 1:nRows
        rowLine = "";
        for c = 1:nCols
            val = string(columns{c}{r});
            rowLine = rowLine + pad(val, widths(c));
        end
        tbx_printf("%s\n", rowLine);
    end
end

function tbx_printError(fmt, varargin)
%TBX_PRINTERROR  Print error message to stderr.
    msg = sprintf(fmt, varargin{:});
    fprintf(2, "Error: %s\n", msg);
end

function tbx_printWarning(fmt, varargin)
%TBX_PRINTWARNING  Print warning message to stderr.
    msg = sprintf(fmt, varargin{:});
    fprintf(2, "Warning: %s\n", msg);
end

function str = tbx_formatBytes(bytes)
%TBX_FORMATBYTES  Format byte count as human-readable string.
    if bytes < 1024
        str = sprintf("%d B", bytes);
    elseif bytes < 1024^2
        str = sprintf("%.1f KB", bytes / 1024);
    elseif bytes < 1024^3
        str = sprintf("%.1f MB", bytes / 1024^2);
    else
        str = sprintf("%.1f GB", bytes / 1024^3);
    end
end

%% ========================================================================
%  Migration from old tbxmanager layout
%  ========================================================================

function tbx_migrateOld()
%TBX_MIGRATEOLD  Detect old-style installation and offer migration.
    selfPath = string(which("tbxmanager"));
    if selfPath == ""
        return;
    end
    selfDir = fileparts(selfPath);
    oldToolboxDir = fullfile(selfDir, "toolboxes");
    if ~isfolder(oldToolboxDir)
        return;
    end

    % Check migration marker
    markerFile = fullfile(tbx_baseDir(), "state", ".migrated_v1");
    if isfile(markerFile)
        return;
    end

    tbx_printf("\n");
    tbx_printf("============================================================\n");
    tbx_printf("  Old tbxmanager installation detected.\n");
    tbx_printf("  Found: %s\n", oldToolboxDir);
    tbx_printf("  tbxmanager v2 uses ~/.tbxmanager/ for storage.\n");
    tbx_printf("============================================================\n");

    reply = input("Migrate old packages to new layout? [Y/n]: ", "s");
    if ~isempty(reply) && ~strcmpi(reply, "y") && ~strcmpi(reply, "yes")
        tbx_printf("Skipping migration. Re-install with 'tbxmanager install'.\n");
        fid = fopen(markerFile, "w");
        if fid ~= -1
            fprintf(fid, "skipped");
            fclose(fid);
        end
        return;
    end

    tbx_printf("Migrating packages...\n");
    packagesDir = fullfile(tbx_baseDir(), "packages");

    listing = dir(oldToolboxDir);
    migrated = 0;
    for i = 1:numel(listing)
        if listing(i).isdir && ~startsWith(listing(i).name, ".")
            pkgName = string(listing(i).name);
            oldPkgDir = fullfile(oldToolboxDir, pkgName);

            % Check for version subdirectories
            vListing = dir(oldPkgDir);
            hasVersionDirs = false;
            for j = 1:numel(vListing)
                if vListing(j).isdir && ~startsWith(vListing(j).name, ".") && ...
                        contains(string(vListing(j).name), ".")
                    hasVersionDirs = true;
                    break;
                end
            end

            if hasVersionDirs
                for j = 1:numel(vListing)
                    if vListing(j).isdir && ~startsWith(vListing(j).name, ".")
                        verName = string(vListing(j).name);
                        srcDir = fullfile(oldPkgDir, verName);
                        destDir = fullfile(packagesDir, pkgName, verName);
                        if ~isfolder(destDir)
                            mkdir(char(destDir));
                        end
                        try
                            copyfile(fullfile(char(srcDir), "*"), char(destDir));
                            meta.name = char(pkgName);
                            meta.version = char(verName);
                            meta.platform = char(tbx_platformArch());
                            meta.sha256 = "";
                            meta.url = "";
                            meta.installed = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'", "TimeZone", "UTC"));
                            meta.dependencies = struct();
                            meta.migrated_from_v1 = true;
                            tbx_writeJson(fullfile(destDir, "meta.json"), meta);
                            tbx_addToPath(pkgName, verName);
                            migrated = migrated + 1;
                            tbx_printf("  Migrated %s@%s\n", pkgName, verName);
                        catch ME
                            tbx_printWarning("Failed to migrate %s@%s: %s", pkgName, verName, ME.message);
                        end
                    end
                end
            else
                verName = "0.0.0";
                destDir = fullfile(packagesDir, pkgName, verName);
                if ~isfolder(destDir)
                    mkdir(char(destDir));
                end
                try
                    copyfile(fullfile(char(oldPkgDir), "*"), char(destDir));
                    meta.name = char(pkgName);
                    meta.version = char(verName);
                    meta.platform = char(tbx_platformArch());
                    meta.sha256 = "";
                    meta.url = "";
                    meta.installed = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'", "TimeZone", "UTC"));
                    meta.dependencies = struct();
                    meta.migrated_from_v1 = true;
                    tbx_writeJson(fullfile(destDir, "meta.json"), meta);
                    tbx_addToPath(pkgName, verName);
                    migrated = migrated + 1;
                    tbx_printf("  Migrated %s (version set to 0.0.0)\n", pkgName);
                catch ME
                    tbx_printWarning("Failed to migrate %s: %s", pkgName, ME.message);
                end
            end
        end
    end

    % Write migration marker
    fid = fopen(markerFile, "w");
    if fid ~= -1
        fprintf(fid, "migrated %d packages on %s", migrated, char(datetime("now")));
        fclose(fid);
    end

    tbx_printf("Migration complete. %d package(s) migrated.\n", migrated);
    tbx_printf("Old toolboxes remain in %s (delete manually if desired).\n\n", oldToolboxDir);
end
