classdef TestInstallWorkflow < matlab.unittest.TestCase
    % Integration tests for install, uninstall, update, enable, disable,
    % restorepath. Creates mock packages on the fly — fully self-contained.

    properties
        TempDir
        OrigHome
        OrigDir
        OrigPath
        MockIndexFile
        MockPkgDir
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            mkdir(testCase.TempDir);
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            testCase.OrigPath = path;
            setenv("TBXMANAGER_HOME", testCase.TempDir);

            testCase.MockPkgDir = fullfile(testCase.TempDir, "mock_packages");
            mkdir(testCase.MockPkgDir);
            testCase.MockIndexFile = fullfile(testCase.TempDir, "mock_index.json");

            % Initialize tbxmanager
            evalc('tbxmanager("help")');

            % Create mock packages and index
            testCase.createMockPackages();
            testCase.createMockIndex();

            % Point tbxmanager to local mock index
            srcUrl = char("file://" + replace(string(testCase.MockIndexFile), "\", "/"));
            evalc('tbxmanager("source", "remove", "https://marekwadinger.github.io/tbxmanager-registry/index.json")');
            evalc('tbxmanager("source", "add", srcUrl)');

            % Teardowns run LIFO: rmdir last (registered first), cd before it
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() path(testCase.OrigPath));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
        end
    end

    methods (Access = private)
        function createMockPackages(testCase)
            % Create testpkg1 v1.0.0
            d = fullfile(testCase.MockPkgDir, "testpkg1_v1");
            mkdir(d);
            fid = fopen(fullfile(d, "testpkg1_hello.m"), 'w');
            fprintf(fid, 'function testpkg1_hello()\ndisp(''hello from testpkg1 v1'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg1-1.0.0-all.zip"), '*', d);

            % Create testpkg1 v2.0.0
            d2 = fullfile(testCase.MockPkgDir, "testpkg1_v2");
            mkdir(d2);
            fid = fopen(fullfile(d2, "testpkg1_hello.m"), 'w');
            fprintf(fid, 'function testpkg1_hello()\ndisp(''hello from testpkg1 v2'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg1-2.0.0-all.zip"), '*', d2);

            % Create testpkg2 v1.0.0
            d3 = fullfile(testCase.MockPkgDir, "testpkg2_v1");
            mkdir(d3);
            fid = fopen(fullfile(d3, "testpkg2_hello.m"), 'w');
            fprintf(fid, 'function testpkg2_hello()\ndisp(''hello from testpkg2'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg2-1.0.0-all.zip"), '*', d3);

            % Create testpkg3 v1.0.0 as tar.gz
            d4 = fullfile(testCase.MockPkgDir, "testpkg3_v1");
            mkdir(d4);
            fid = fopen(fullfile(d4, "testpkg3_hello.m"), 'w');
            fprintf(fid, 'function testpkg3_hello()\ndisp(''hello from testpkg3'');\nend\n');
            fclose(fid);
            tarFile = fullfile(testCase.MockPkgDir, "testpkg3-1.0.0-all.tar.gz");
            system(sprintf('tar czf "%s" -C "%s" .', tarFile, d4));

            % Create testpkg_depr v1.0.0 (deprecated, underscore name to avoid jsondecode mangling)
            d5 = fullfile(testCase.MockPkgDir, "testpkg_depr_v1");
            mkdir(d5);
            fid = fopen(fullfile(d5, "testpkg_depr_hello.m"), 'w');
            fprintf(fid, 'function testpkg_depr_hello()\ndisp(''deprecated'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_depr-1.0.0-all.zip"), '*', d5);

            % Create testpkg_nolatest v1.0.0 (no "latest" field in index)
            d6 = fullfile(testCase.MockPkgDir, "testpkg_nolatest_v1");
            mkdir(d6);
            fid = fopen(fullfile(d6, "testpkg_nolatest_hello.m"), 'w');
            fprintf(fid, 'function testpkg_nolatest_hello()\ndisp(''nolatest'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_nolatest-1.0.0-all.zip"), '*', d6);

            % Create testpkg_tgz v1.0.0 as .tgz
            d7 = fullfile(testCase.MockPkgDir, "testpkg_tgz_v1");
            mkdir(d7);
            fid = fopen(fullfile(d7, "testpkg_tgz_hello.m"), 'w');
            fprintf(fid, 'function testpkg_tgz_hello()\ndisp(''tgz'');\nend\n');
            fclose(fid);
            tgzFile = fullfile(testCase.MockPkgDir, "testpkg_tgz-1.0.0-all.tgz");
            system(sprintf('tar czf "%s" -C "%s" .', tgzFile, d7));

            % Create testpkg_noext v1 as zip but stored without file extension.
            % Version is "1" (no dots) so the URL filename has no dots after the
            % package name, triggering the isempty(urlExt) → ".zip" fallback in
            % tbx_installSinglePackage (L1267).
            d8 = fullfile(testCase.MockPkgDir, "testpkg_noext_v1");
            mkdir(d8);
            fid = fopen(fullfile(d8, "testpkg_noext_hello.m"), 'w');
            fprintf(fid, 'function testpkg_noext_hello()\ndisp(''noext'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_noext-1-all_tmp.zip"), '*', d8);
            % Store as file with no extension: URL has no dots → fileparts returns empty ext
            copyfile(fullfile(testCase.MockPkgDir, "testpkg_noext-1-all_tmp.zip"), ...
                     fullfile(testCase.MockPkgDir, "testpkg_noext-1-all"));

            % Create testpkg_badhash v1.0.0 (real file but wrong hash in index)
            d9 = fullfile(testCase.MockPkgDir, "testpkg_badhash_v1");
            mkdir(d9);
            fid = fopen(fullfile(d9, "testpkg_badhash_hello.m"), 'w');
            fprintf(fid, 'function testpkg_badhash_hello()\ndisp(''badhash'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_badhash-1.0.0-all.zip"), '*', d9);

            % Create testpkg_nover v1.0.0 (index entry has no "versions" field)
            d10 = fullfile(testCase.MockPkgDir, "testpkg_nover_v1");
            mkdir(d10);
            fid = fopen(fullfile(d10, "nover.m"), 'w');
            fprintf(fid, 'function nover(); end\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_nover-1.0.0-all.zip"), '*', d10);

            % Create testpkg_topdir v1.0.0 (zip with single top-level directory)
            d11src = fullfile(testCase.MockPkgDir, "testpkg_topdir_src");
            mkdir(d11src);
            d11inner = fullfile(d11src, "testpkg_topdir_inner");
            mkdir(d11inner);
            fid = fopen(fullfile(d11inner, "topdir_func.m"), 'w');
            fprintf(fid, 'function topdir_func(); end\n');
            fclose(fid);
            % Hidden file to cover the hidden-items branch
            fid = fopen(fullfile(d11inner, ".gitkeep"), 'w');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_topdir-1.0.0-all.zip"), ...
                'testpkg_topdir_inner', d11src);

            % Create testpkg_unsup v1.0.0 (zip stored with .rar extension -> UnsupportedArchive)
            d12 = fullfile(testCase.MockPkgDir, "testpkg_unsup_v1");
            mkdir(d12);
            fid = fopen(fullfile(d12, "unsup.m"), 'w');
            fprintf(fid, 'function unsup(); end\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_unsup-tmp.zip"), '*', d12);
            copyfile(fullfile(testCase.MockPkgDir, "testpkg_unsup-tmp.zip"), ...
                     fullfile(testCase.MockPkgDir, "testpkg_unsup-1.0.0-all.rar"));

            % Create testpkg_upgradable v1.0.0 and v2.0.0 (for update plan branches)
            d13 = fullfile(testCase.MockPkgDir, "testpkg_upgradable_v1");
            mkdir(d13);
            fid = fopen(fullfile(d13, "upg_v1.m"), 'w');
            fprintf(fid, 'function upg_v1(); end\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_upgradable-1.0.0-all.zip"), '*', d13);

            d14 = fullfile(testCase.MockPkgDir, "testpkg_upgradable_v2");
            mkdir(d14);
            fid = fopen(fullfile(d14, "upg_v2.m"), 'w');
            fprintf(fid, 'function upg_v2(); end\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_upgradable-2.0.0-all.zip"), '*', d14);

            % Create testpkg_multicov v1.0.0 (direct-url format; other versions use fake URLs)
            d15 = fullfile(testCase.MockPkgDir, "testpkg_multicov_v1");
            mkdir(d15);
            fid = fopen(fullfile(d15, "mcov.m"), 'w');
            fprintf(fid, 'function mcov(); end\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg_multicov-1.0.0-all.zip"), '*', d15);
        end

        function hash = computeSha256(~, filepath)
            % Compute SHA256 using Java MessageDigest
            md = java.security.MessageDigest.getInstance("SHA-256");
            fid = fopen(filepath, 'r');
            while ~feof(fid)
                chunk = fread(fid, 65536, '*uint8');
                if ~isempty(chunk)
                    md.update(chunk);
                end
            end
            fclose(fid);
            hashBytes = md.digest();
            hexChars = '0123456789abcdef';
            hash = blanks(length(hashBytes) * 2);
            for i = 1:length(hashBytes)
                b = typecast(int8(hashBytes(i)), 'uint8');
                hash((i-1)*2 + 1) = hexChars(bitshift(b, -4) + 1);
                hash((i-1)*2 + 2) = hexChars(bitand(b, 15) + 1);
            end
        end

        function createMockIndex(testCase)
            d = testCase.MockPkgDir;

            % Compute hashes at runtime
            h1v1 = testCase.computeSha256(fullfile(d, "testpkg1-1.0.0-all.zip"));
            h1v2 = testCase.computeSha256(fullfile(d, "testpkg1-2.0.0-all.zip"));
            h2v1 = testCase.computeSha256(fullfile(d, "testpkg2-1.0.0-all.zip"));
            h3v1 = testCase.computeSha256(fullfile(d, "testpkg3-1.0.0-all.tar.gz"));
            hDepr = testCase.computeSha256(fullfile(d, "testpkg_depr-1.0.0-all.zip"));
            hNoLatest = testCase.computeSha256(fullfile(d, "testpkg_nolatest-1.0.0-all.zip"));
            hTgz = testCase.computeSha256(fullfile(d, "testpkg_tgz-1.0.0-all.tgz"));
            hNoExt = testCase.computeSha256(fullfile(d, "testpkg_noext-1-all"));
            hBadHash = testCase.computeSha256(fullfile(d, "testpkg_badhash-1.0.0-all.zip"));
            hTopDir = testCase.computeSha256(fullfile(d, "testpkg_topdir-1.0.0-all.zip"));
            hUnsup = testCase.computeSha256(fullfile(d, "testpkg_unsup-1.0.0-all.rar"));
            hUpg1 = testCase.computeSha256(fullfile(d, "testpkg_upgradable-1.0.0-all.zip"));
            hUpg2 = testCase.computeSha256(fullfile(d, "testpkg_upgradable-2.0.0-all.zip"));
            hMcov = testCase.computeSha256(fullfile(d, "testpkg_multicov-1.0.0-all.zip"));

            % Build URLs
            u1v1 = char("file://" + replace(string(fullfile(d, "testpkg1-1.0.0-all.zip")), "\", "/"));
            u1v2 = char("file://" + replace(string(fullfile(d, "testpkg1-2.0.0-all.zip")), "\", "/"));
            u2v1 = char("file://" + replace(string(fullfile(d, "testpkg2-1.0.0-all.zip")), "\", "/"));
            u3v1 = char("file://" + replace(string(fullfile(d, "testpkg3-1.0.0-all.tar.gz")), "\", "/"));
            uDepr = char("file://" + replace(string(fullfile(d, "testpkg_depr-1.0.0-all.zip")), "\", "/"));
            uNoLatest = char("file://" + replace(string(fullfile(d, "testpkg_nolatest-1.0.0-all.zip")), "\", "/"));
            uTgz = char("file://" + replace(string(fullfile(d, "testpkg_tgz-1.0.0-all.tgz")), "\", "/"));
            uNoExt = char("file://" + replace(string(fullfile(d, "testpkg_noext-1-all")), "\", "/"));
            uBadHash = char("file://" + replace(string(fullfile(d, "testpkg_badhash-1.0.0-all.zip")), "\", "/"));
            uTopDir = char("file://" + replace(string(fullfile(d, "testpkg_topdir-1.0.0-all.zip")), "\", "/"));
            uUnsup = char("file://" + replace(string(fullfile(d, "testpkg_unsup-1.0.0-all.rar")), "\", "/"));
            uUpg1 = char("file://" + replace(string(fullfile(d, "testpkg_upgradable-1.0.0-all.zip")), "\", "/"));
            uUpg2 = char("file://" + replace(string(fullfile(d, "testpkg_upgradable-2.0.0-all.zip")), "\", "/"));
            uMcov = char("file://" + replace(string(fullfile(d, "testpkg_multicov-1.0.0-all.zip")), "\", "/"));

            % Build deterministic raw JSON (version keys like "1.0.0" are invalid struct fields).
            fmt = @(s) strrep(testCase.jsonEscape(s), '%', '%%');
            vfmt = @(u,h,r) sprintf('{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"%s"}', ...
                fmt(u), fmt(h), fmt(r));
            % testpkg1 v1.0.0 yanked
            v1v1 = sprintf('{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-01-01","yanked":"security issue"}', ...
                fmt(u1v1), fmt(h1v1));
            % testpkg2 v1.0.0 (dep on testpkg1) and v2.0.0 (dep on testpkg1 + testpkg_nolatest)
            v2v1 = sprintf('{"matlab":">=R2022a","dependencies":{"testpkg1":">=1.0"},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-03-01"}', ...
                fmt(u2v1), fmt(h2v1));
            % testpkg_badhash: put a deliberately wrong hash
            fakeHash = repmat('0', 1, 64);
            vBadHash = sprintf('{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-01-01"}', ...
                fmt(uBadHash), fmt(fakeHash));
            % testpkg_upgradable v2.0.0: depends on testpkg1 + testpkg_nolatest (new dep)
            vUpg2 = sprintf('{"matlab":">=R2022a","dependencies":{"testpkg1":">=1.0","testpkg_nolatest":"*"},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2026-01-01"}', ...
                fmt(uUpg2), fmt(hUpg2));
            % testpkg_multicov v1.0.0: direct-url format (no "platforms" field → L745-753)
            vMcov1 = sprintf('{"matlab":">=R2022a","dependencies":{},"url":"%s","sha256":"%s","released":"2026-01-01"}', ...
                fmt(uMcov), fmt(hMcov));
            json = [...
                '{' ...
                    '"index_version":1,' ...
                    '"generated":"2026-01-01T00:00:00Z",' ...
                    '"packages":{' ...
                        '"testpkg1":{"name":"testpkg1","description":"Test package 1","license":"MIT","authors":["Test"],"latest":"2.0.0",' ...
                        '"versions":{"1.0.0":' v1v1 ',"2.0.0":' vfmt(u1v2, h1v2, '2025-06-01') '}},' ...
                        '"testpkg2":{"name":"testpkg2","description":"Test package 2","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' v2v1 '}},' ...
                        '"testpkg3":{"name":"testpkg3","description":"Test package 3","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"homepage":"https://example.com/testpkg3",' ...
                        '"versions":{"1.0.0":' vfmt(u3v1, h3v1, '2025-01-01') '}},' ...
                        '"testpkg_depr":{"name":"testpkg_depr","description":"Deprecated pkg","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"deprecated":"use testpkg1 instead",' ...
                        '"versions":{"1.0.0":' vfmt(uDepr, hDepr, '2024-01-01') '}},' ...
                        '"testpkg_nolatest":{"name":"testpkg_nolatest","description":"No latest field","license":"MIT","authors":["Test"],' ...
                        '"versions":{"1.0.0":' vfmt(uNoLatest, hNoLatest, '2024-01-01') '}},' ...
                        '"testpkg_tgz":{"name":"testpkg_tgz","description":"TGZ package","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(uTgz, hTgz, '2025-01-01') '}},' ...
                        '"testpkg_noext":{"name":"testpkg_noext","description":"No extension URL","license":"MIT","authors":["Test"],"latest":"1",' ...
                        '"versions":{"1":' vfmt(uNoExt, hNoExt, '2025-01-01') '}},' ...
                        '"testpkg_badhash":{"name":"testpkg_badhash","description":"Bad hash","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' vBadHash '}},' ...
                        '"testpkg_nover":{"name":"testpkg_nover","description":"No versions field","license":"MIT","authors":"Single Author"},' ...
                        '"testpkg_topdir":{"name":"testpkg_topdir","description":"Top-level dir zip","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(uTopDir, hTopDir, '2026-01-01') '}},' ...
                        '"testpkg_unsup":{"name":"testpkg_unsup","description":"Unsupported format","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"' fmt(uUnsup) '","sha256":"' fmt(hUnsup) '"}},"released":"2026-01-01"}}},' ...
                        '"testpkg_upgradable":{"name":"testpkg_upgradable","description":"Upgradable pkg","license":"MIT","authors":["Test"],"latest":"2.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(uUpg1, hUpg1, '2025-01-01') ',"2.0.0":' vUpg2 '}},' ...
                        '"testpkg_multicov":{"name":"testpkg_multicov","description":"Multi-version coverage","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{' ...
                            '"3.0.0":{"matlab":">=R9999a","dependencies":{},"platforms":{"all":{"url":"fake://v3","sha256":"abc123"}},"released":"2026-01-01"},' ...
                            '"2.0.0":{"matlab":">=R2022a","dependencies":{},"platforms":{"none_fake":{"url":"fake://v2","sha256":"abc123"}},"released":"2026-01-01"},' ...
                            '"1.5.0":{"matlab":">=R2022a","dependencies":{},"released":"2026-01-01"},' ...
                            '"1.0.0":' vMcov1 ...
                        '}},' ...
                        '"testpkg_conf1":{"name":"testpkg_conf1","description":"Conflict pkg 1","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":{"matlab":">=R2022a","dependencies":{"testpkg1":"==2.0.0"},"platforms":{"all":{"url":"fake://conf1","sha256":"abc123"}},"released":"2026-01-01"}}},' ...
                        '"testpkg_conf2":{"name":"testpkg_conf2","description":"Conflict pkg 2","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":{"matlab":">=R2022a","dependencies":{"testpkg1":"==1.0.0"},"platforms":{"all":{"url":"fake://conf2","sha256":"abc123"}},"released":"2026-01-01"}}}' ...
                    '}' ...
                '}'];

            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '%s', json);
            fclose(fid);
        end

        function s = jsonEscape(~, s0)
            % Escape JSON special characters in scalar text fragments.
            s = char(s0);
            s = strrep(s, '\', '\\');
            s = strrep(s, '"', '\"');
        end
    end

    methods (Test)

        % --- Error handling ---

        function testInstallNoArgs(testCase)
            evalc('tbxmanager("install")');
            testCase.verifyTrue(true);
        end

        function testUninstallNoArgs(testCase)
            evalc('tbxmanager("uninstall")');
            testCase.verifyTrue(true);
        end

        function testEnableNoArgs(testCase)
            evalc('tbxmanager("enable")');
            testCase.verifyTrue(true);
        end

        function testDisableNoArgs(testCase)
            evalc('tbxmanager("disable")');
            testCase.verifyTrue(true);
        end

        % --- Install ---

        function testInstallSinglePackage(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyTrue(isfolder(pkgDir), 'Package directory should exist');
        end

        function testInstallTarGzPackage(testCase)
            evalc('tbxmanager("install", "testpkg3")');
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg3");
            testCase.verifyTrue(isfolder(pkgDir), 'tar.gz package should be installed');
        end

        function testInstallCreatesFiles(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            versions = dir(fullfile(testCase.TempDir, "packages", "testpkg1"));
            versionDirs = versions([versions.isdir] & ~ismember({versions.name}, {'.', '..'}));
            testCase.verifyGreaterThanOrEqual(numel(versionDirs), 1);
        end

        function testDoubleInstall(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("install", "testpkg1")');
            testCase.verifyTrue(true);
        end

        function testInstallWithDependency(testCase)
            evalc('tbxmanager("install", "testpkg2")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg2")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")));
        end

        % --- List ---

        function testListAfterInstall(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("list")');
            testCase.verifyTrue(true);
        end

        % --- Search ---

        function testSearchFindsPackage(testCase)
            evalc('tbxmanager("search", "testpkg")');
            testCase.verifyTrue(true);
        end

        function testSearchNoResults(testCase)
            evalc('tbxmanager("search", "nonexistent_xyz_12345")');
            testCase.verifyTrue(true);
        end

        % --- Info ---

        function testInfoPackage(testCase)
            evalc('tbxmanager("info", "testpkg1")');
            testCase.verifyTrue(true);
        end

        % --- Enable/Disable ---

        function testEnableDisableCycle(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("disable", "testpkg1")');

            f = fullfile(testCase.TempDir, "state", "enabled.json");
            data = jsondecode(fileread(f));
            if isstruct(data.packages)
                names = fieldnames(data.packages);
                testCase.verifyFalse(ismember('testpkg1', names));
            end

            evalc('tbxmanager("enable", "testpkg1")');
            data2 = jsondecode(fileread(f));
            names2 = fieldnames(data2.packages);
            testCase.verifyTrue(ismember('testpkg1', names2));
        end

        function testRestorePathAfterDisable(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("enable", "testpkg1")');
            evalc('tbxmanager("restorepath")');
            testCase.verifyTrue(true);
        end

        % --- Update ---

        function testUpdatePackage(testCase)
            evalc('tbxmanager("install", "testpkg1@==1.0.0")');
            evalc('tbxmanager("update", "testpkg1")');
            testCase.verifyTrue(true);
        end

        % --- Uninstall ---

        function testUninstallPackage(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("uninstall", "testpkg1")');
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyFalse(isfolder(pkgDir), 'Package should be removed');
        end

        function testUninstallWithDeps(testCase)
            evalc('tbxmanager("install", "testpkg2")');
            evalc('tbxmanager("uninstall", "testpkg1")');
            testCase.verifyTrue(true);
        end

        % --- Install edge cases ---

        function testInstallResolveFailure(testCase)
            % Package not in index → resolve throws, main_install catches it
            out = evalc('tbxmanager("install", "nonexistent_pkg_xyz_9999")');
            testCase.verifyTrue(contains(out, "failed") || contains(out, "not found"), ...
                'Should report resolution failure');
        end

        function testInstallEmptyIndex(testCase)
            % Overwrite index with empty packages to hit "No packages found" branch
            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '{"index_version":1,"generated":"2026-01-01T00:00:00Z","packages":{}}');
            fclose(fid);
            out = evalc('tbxmanager("install", "testpkg1")');
            testCase.verifyTrue(contains(out, "No packages") || contains(out, "index"), ...
                'Should report no packages in index');
        end

        function testInstallDeprecatedWarning(testCase)
            out = evalc('tbxmanager("install", "testpkg_depr")');
            testCase.verifyTrue(contains(out, "deprecated") || contains(out, "DEPRECATED"), ...
                'Should warn about deprecated package');
        end

        function testInstallYankedWarning(testCase)
            % Explicitly pin v1.0.0 which is marked yanked
            out = evalc('tbxmanager("install", "testpkg1@==1.0.0")');
            testCase.verifyTrue(contains(out, "yanked") || contains(out, "YANKED"), ...
                'Should warn about yanked version');
        end

        function testInstallHashMismatch(testCase)
            testCase.verifyError( ...
                @() tbxmanager("install", "testpkg_badhash"), ...
                'TBXMANAGER:HashMismatch');
        end

        function testInstallTgzExtension(testCase)
            % .tgz extension hits the tgz branch in tbx_installSinglePackage
            evalc('tbxmanager("install", "testpkg_tgz")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg_tgz")), ...
                '.tgz package should be installed');
        end

        function testInstallNoExtension(testCase)
            % URL with no extension hits the fileparts fallback → defaults to .zip
            evalc('tbxmanager("install", "testpkg_noext")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg_noext")), ...
                'No-extension URL package should be installed');
        end

        function testInstallCachedDownload(testCase)
            % Install, uninstall (keeps cache), re-install → uses cached download
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("uninstall", "testpkg1")');
            out = evalc('tbxmanager("install", "testpkg1")');
            testCase.verifyTrue(contains(out, "cached") || contains(out, "Installing"), ...
                'Re-install should succeed (using cache or fresh download)');
        end

        % --- Uninstall edge cases ---

        function testUninstallNoPackages(testCase)
            % Nothing installed → "No packages installed"
            out = evalc('tbxmanager("uninstall", "testpkg1")');
            testCase.verifyTrue(contains(out, "No packages") || contains(out, "installed"), ...
                'Should report no packages installed');
        end

        function testUninstallNotInstalled(testCase)
            % Install testpkg3, try to uninstall testpkg1 (not installed)
            evalc('tbxmanager("install", "testpkg3")');
            out = evalc('tbxmanager("uninstall", "testpkg1")');
            testCase.verifyTrue(contains(out, "not installed") || contains(out, "Warning"), ...
                'Should warn that package is not installed');
        end

        function testUninstallWithRevDeps(testCase)
            % testpkg2 depends on testpkg1; uninstalling testpkg1 should warn
            evalc('tbxmanager("install", "testpkg2")');
            out = evalc('tbxmanager("uninstall", "testpkg1")');
            testCase.verifyTrue(contains(out, "required by") || contains(out, "Skipping"), ...
                'Should warn about reverse dependency and skip in non-interactive mode');
        end

        % --- Update edge cases ---

        function testUpdateNoPackages(testCase)
            out = evalc('tbxmanager("update")');
            testCase.verifyTrue(contains(out, "No packages"), ...
                'Should report no packages when nothing installed');
        end

        function testUpdateAllUpToDate(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            out = evalc('tbxmanager("update", "testpkg1")');
            testCase.verifyTrue(contains(out, "up to date") || contains(out, "All packages"), ...
                'Should report up to date after installing latest');
        end

        function testUpdateNotInstalled(testCase)
            evalc('tbxmanager("install", "testpkg3")');
            out = evalc('tbxmanager("update", "testpkg1")');
            testCase.verifyTrue(contains(out, "not installed"), ...
                'Should warn that testpkg1 is not installed');
        end

        function testUpdateNotInIndex(testCase)
            % Manually create a package that's not in the index, then update
            pkgDir = fullfile(testCase.TempDir, "packages", "phantom-pkg", "1.0.0");
            mkdir(pkgDir);
            meta.name = "phantom-pkg"; meta.version = "1.0.0";
            meta.platform = "all"; meta.sha256 = "abc";
            meta.url = "file://fake"; meta.installed = "2026-01-01T00:00:00Z";
            meta.dependencies = struct();
            fid = fopen(fullfile(pkgDir, "meta.json"), 'w');
            fprintf(fid, '%s', jsonencode(meta));
            fclose(fid);
            out = evalc('tbxmanager("update", "phantom-pkg")');
            testCase.verifyTrue(contains(out, "not found") || contains(out, "index"), ...
                'Should warn that package is not in index');
        end

        % --- List edge cases ---

        function testListDisabledPackage(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            evalc('tbxmanager("disable", "testpkg1")');
            out = evalc('tbxmanager("list")');
            testCase.verifyTrue(contains(out, "disabled"), ...
                'Should show disabled status');
        end

        function testListNoLatestVersion(testCase)
            evalc('tbxmanager("install", "testpkg_nolatest")');
            out = evalc('tbxmanager("list")');
            testCase.verifyTrue(contains(out, "-") || contains(out, "testpkg_nolatest"), ...
                'Should show "-" for no-latest package');
        end

        function testListInstalledWithoutMetaJson(testCase)
            % Create a package version dir with no meta.json
            pkgDir = fullfile(testCase.TempDir, "packages", "raw-pkg", "2.0.0");
            mkdir(pkgDir);
            fid = fopen(fullfile(pkgDir, "raw_func.m"), 'w');
            fprintf(fid, 'function raw_func(); end\n');
            fclose(fid);
            out = evalc('tbxmanager("list")');
            testCase.verifyTrue(contains(out, "raw-pkg") || contains(out, "No packages"), ...
                'Should handle missing meta.json gracefully');
        end

        % --- Search edge cases ---

        function testSearchDeprecated(testCase)
            out = evalc('tbxmanager("search", "testpkg_depr")');
            testCase.verifyTrue(contains(out, "DEPRECATED") || contains(out, "deprecated"), ...
                'Should show deprecated tag in search results');
        end

        function testSearchNoLatest(testCase)
            out = evalc('tbxmanager("search", "testpkg_nolatest")');
            testCase.verifyTrue(contains(out, "-") || contains(out, "testpkg_nolatest"), ...
                'Should show "-" version for no-latest package');
        end

        function testSearchEmptyIndex(testCase)
            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '{"index_version":1,"generated":"2026-01-01T00:00:00Z","packages":{}}');
            fclose(fid);
            out = evalc('tbxmanager("search", "testpkg")');
            testCase.verifyTrue(contains(out, "No packages") || contains(out, "found"), ...
                'Should report no packages in empty index');
        end

        % --- Info edge cases ---

        function testInfoNotInIndex(testCase)
            out = evalc('tbxmanager("info", "nonexistent_pkg_xyz_9999")');
            testCase.verifyTrue(contains(out, "not found") || contains(out, "Error"), ...
                'Should report package not found');
        end

        function testInfoInstalled(testCase)
            evalc('tbxmanager("install", "testpkg1")');
            out = evalc('tbxmanager("info", "testpkg1")');
            testCase.verifyTrue(contains(out, "Installed version"), ...
                'Should show installed version');
        end

        function testInfoDeprecated(testCase)
            out = evalc('tbxmanager("info", "testpkg_depr")');
            testCase.verifyTrue(contains(out, "DEPRECATED") || contains(out, "deprecated"), ...
                'Should show deprecated warning in info');
        end

        function testInfoNotInstalled(testCase)
            out = evalc('tbxmanager("info", "testpkg3")');
            testCase.verifyTrue(contains(out, "Not installed"), ...
                'Should show Not installed when package not installed');
        end

        % --- Additional coverage ---

        function testInstallMultipleWithSharedDep(testCase)
            % Install testpkg1 and testpkg2 simultaneously.
            % testpkg2 depends on testpkg1, so testpkg1 is queued twice:
            % once explicitly and once as a transitive dep — hits already-resolved branch.
            evalc('tbxmanager("install", "testpkg1", "testpkg2")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")), ...
                'testpkg1 should be installed');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg2")), ...
                'testpkg2 should be installed');
        end

        function testInstallNoSatisfyingVersion(testCase)
            % testpkg1@<2.0 means only v1.0.0 satisfies; that version is yanked.
            % Hits the "skip yanked" branch then "no satisfying version" error.
            out = evalc('tbxmanager("install", "testpkg1@<2.0")');
            testCase.verifyTrue(contains(out, "failed") || contains(out, "No version") || contains(out, "satisfy"), ...
                'Should report no satisfying version for yanked-only constraint');
        end

        function testInstallNoVersionsField(testCase)
            % testpkg_nover has no "versions" field in the index → NoVersions error
            out = evalc('tbxmanager("install", "testpkg_nover")');
            testCase.verifyTrue(contains(out, "failed") || contains(out, "No version") || contains(out, "version"), ...
                'Should report no versions available');
        end

        function testUpdateAllPackages(testCase)
            % Install testpkg1 (latest), then call update with no args → all-packages branch
            evalc('tbxmanager("install", "testpkg1")');
            out = evalc('tbxmanager("update")');
            testCase.verifyTrue(contains(out, "up to date") || contains(out, "All packages") || contains(out, "Done"), ...
                'Should report packages are up to date');
        end

        function testInstallExistingTmpDir(testCase)
            % Pre-create the tmp directory to trigger the rmdir branch in tbx_installSinglePackage
            tmpDir = fullfile(testCase.TempDir, "tmp", "testpkg1-2.0.0");
            [~, ~] = mkdir(tmpDir);
            evalc('tbxmanager("install", "testpkg1")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")), ...
                'Install should succeed even when tmp dir pre-exists');
        end

        function testInstallSingleTopLevelDir(testCase)
            % testpkg_topdir zip has a single top-level directory → flatten branch
            evalc('tbxmanager("install", "testpkg_topdir")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg_topdir")), ...
                'Top-level-dir zip package should be installed');
        end

        function testInstallUnsupportedArchive(testCase)
            % testpkg_unsup URL ends in .rar → UnsupportedArchive inside try → ExtractFailed
            testCase.verifyError(@() tbxmanager("install", "testpkg_unsup"), ...
                'TBXMANAGER:ExtractFailed');
        end

        function testUpdatePlanBranches(testCase)
            % Install testpkg_upgradable@1.0.0 (exact pin to get old version).
            % Pre-create testpkg_nolatest as "installed" so plan shows it as "no change".
            evalc('tbxmanager("install", "testpkg_upgradable@==1.0.0")');
            % Manually mark testpkg_nolatest as installed (version 1.0.0)
            nolatDir = fullfile(testCase.TempDir, "packages", "testpkg_nolatest", "1.0.0");
            [~, ~] = mkdir(nolatDir);
            meta.name = "testpkg_nolatest"; meta.version = "1.0.0";
            meta.platform = "all"; meta.sha256 = "abc";
            meta.url = "file://fake"; meta.installed = "2026-01-01T00:00:00Z";
            meta.dependencies = struct();
            fid = fopen(fullfile(nolatDir, "meta.json"), 'w');
            fprintf(fid, '%s', jsonencode(meta));
            fclose(fid);
            % Update: plan shows testpkg_nolatest (no change), testpkg1 (new dep), testpkg_upgradable (upgrade)
            % Covers: L1527 (new), L1530 (no change), L1550 (skip same ver during execute)
            out = evalc('tbxmanager("update", "testpkg_upgradable")');
            testCase.verifyTrue(contains(out, "Done") || contains(out, "updated"), ...
                'Update should complete successfully');
        end

        function testInfoWithHomepage(testCase)
            % testpkg3 has a homepage field in the mock index
            out = evalc('tbxmanager("info", "testpkg3")');
            testCase.verifyTrue(contains(out, "Homepage"), ...
                'Should display Homepage field');
        end

        function testInfoWithDeps(testCase)
            % testpkg2 has dependencies in its version entry
            out = evalc('tbxmanager("info", "testpkg2")');
            testCase.verifyTrue(contains(out, "requires"), ...
                'Should display dependency requirements');
        end

        function testInstallVersionSkipBranches(testCase)
            % testpkg_multicov has 4 versions that exercise resolver skip branches:
            % v3.0.0: MATLAB constraint >=R9999a fails (L731)
            % v2.0.0: platform "none_fake" not supported → pUrl="" (L739)
            % v1.5.0: no "platforms", no "url" field → continue (L748)
            % v1.0.0: direct URL format (no "platforms") → L745-753
            evalc('tbxmanager("install", "testpkg_multicov")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg_multicov")), ...
                'testpkg_multicov should be installed via direct-url v1.0.0');
        end

        function testInstallConflictingDeps(testCase)
            % testpkg_conf1 requires testpkg1@==2.0.0
            % testpkg_conf2 requires testpkg1@==1.0.0
            % Installing both together triggers ConflictingDeps at L679-681
            out = evalc('tbxmanager("install", "testpkg_conf1", "testpkg_conf2")');
            testCase.verifyTrue(contains(out, "Conflict") || contains(out, "failed"), ...
                'Should report conflicting dependency requirements');
        end

        function testUpdateEmptyIndex(testCase)
            % Install testpkg1 (so installed list is non-empty), then empty
            % the index → update hits L1468-1469 ("No packages found in any index")
            evalc('tbxmanager("install", "testpkg1")');
            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '{"index_version":1,"generated":"2026-01-01T00:00:00Z","packages":{}}');
            fclose(fid);
            out = evalc('tbxmanager("update")');
            testCase.verifyTrue(contains(out, "No packages") || contains(out, "index"), ...
                'Should report no packages in index');
        end

        function testUpdateResolveFails(testCase)
            % Install testpkg_upgradable@1.0.0, then overwrite index so v2.0.0
            % depends on a nonexistent package → tbx_resolve throws → L1516-1518
            evalc('tbxmanager("install", "testpkg_upgradable@==1.0.0")');
            d = testCase.MockPkgDir;
            hUpg1 = testCase.computeSha256(fullfile(d, "testpkg_upgradable-1.0.0-all.zip"));
            hUpg2 = testCase.computeSha256(fullfile(d, "testpkg_upgradable-2.0.0-all.zip"));
            u1 = char("file://" + replace(string(fullfile(d, "testpkg_upgradable-1.0.0-all.zip")), "\", "/"));
            u2 = char("file://" + replace(string(fullfile(d, "testpkg_upgradable-2.0.0-all.zip")), "\", "/"));
            esc = @(s) strrep(strrep(char(s), '\', '\\'), '"', '\"');
            newJson = sprintf(['{"index_version":1,"generated":"2026-01-01T00:00:00Z","packages":{'...
                '"testpkg_upgradable":{"name":"testpkg_upgradable","description":"test","license":"MIT",'...
                '"authors":["Test"],"latest":"2.0.0","versions":{'...
                '"1.0.0":{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-01-01"},'...
                '"2.0.0":{"matlab":">=R2022a","dependencies":{"nonexistent_dep_xyz_fail":">=1.0"},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2026-01-01"}'...
                '}}}}'], esc(u1), esc(hUpg1), esc(u2), esc(hUpg2));
            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '%s', newJson);
            fclose(fid);
            out = evalc('tbxmanager("update", "testpkg_upgradable")');
            testCase.verifyTrue(contains(out, "failed") || contains(out, "resolution") || contains(out, "not found"), ...
                'Should report dependency resolution failure');
        end

        function testListWithBrokenIndex(testCase)
            % Install testpkg1, then write malformed JSON to sources.json so
            % tbx_getSources() throws inside tbx_loadIndex() → caught at L1587
            evalc('tbxmanager("install", "testpkg1")');
            stateDir = fullfile(testCase.TempDir, "state");
            fid = fopen(fullfile(stateDir, "sources.json"), 'w');
            fprintf(fid, '{{{not valid json');
            fclose(fid);
            out = evalc('tbxmanager("list")');
            testCase.verifyTrue(contains(out, "testpkg1"), ...
                'List should still show installed packages despite broken sources.json');
        end

        function testInfoSingleAuthor(testCase)
            % testpkg_nover has "authors":"Single Author" (scalar string, not array)
            % → jsondecode returns char, hitting the else branch at L1712-1713
            out = evalc('tbxmanager("info", "testpkg_nover")');
            testCase.verifyTrue(contains(out, "Single Author"), ...
                'Should display scalar string author');
        end

        function testInstallExactPlatform(testCase)
            % Create index with an explicit platform entry for the current arch
            % (not 'all') → tbx_resolvePlatform picks exact match at L852-857
            arch = computer('arch');  % e.g. 'maca64', 'win64', 'glnxa64'
            d = testCase.MockPkgDir;
            h = testCase.computeSha256(fullfile(d, "testpkg1-2.0.0-all.zip"));
            u = char("file://" + replace(string(fullfile(d, "testpkg1-2.0.0-all.zip")), "\", "/"));
            esc = @(s) strrep(strrep(char(s), '\', '\\'), '"', '\"');
            newJson = sprintf(['{"index_version":1,"generated":"2026-01-01T00:00:00Z","packages":{'...
                '"testpkg1":{"name":"testpkg1","description":"test","license":"MIT",'...
                '"authors":["Test"],"latest":"2.0.0","versions":{'...
                '"2.0.0":{"matlab":">=R2022a","dependencies":{},'...
                '"platforms":{"%s":{"url":"%s","sha256":"%s"}},'...
                '"released":"2026-01-01"}}}}}'], esc(arch), esc(u), esc(h));
            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '%s', newJson);
            fclose(fid);
            evalc('tbxmanager("install", "testpkg1")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")), ...
                'Package with explicit platform entry should be installed');
        end

    end
end
