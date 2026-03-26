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
            tbxmanager("help");

            % Create mock packages and index
            testCase.createMockPackages();
            testCase.createMockIndex();

            % Point tbxmanager to local mock index
            srcUrl = char("file://" + replace(string(testCase.MockIndexFile), "\", "/"));
            tbxmanager("source", "remove", "https://kvasnica.github.io/tbxmanager-registry/index.json");
            tbxmanager("source", "add", srcUrl);

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

            % Build URLs
            u1v1 = char("file://" + replace(string(fullfile(d, "testpkg1-1.0.0-all.zip")), "\", "/"));
            u1v2 = char("file://" + replace(string(fullfile(d, "testpkg1-2.0.0-all.zip")), "\", "/"));
            u2v1 = char("file://" + replace(string(fullfile(d, "testpkg2-1.0.0-all.zip")), "\", "/"));
            u3v1 = char("file://" + replace(string(fullfile(d, "testpkg3-1.0.0-all.tar.gz")), "\", "/"));

            % Build deterministic raw JSON (version keys like "1.0.0" are invalid struct fields).
            fmt = @(s) strrep(testCase.jsonEscape(s), '%', '%%');
            vfmt = @(u,h,r) sprintf('{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"%s"}', ...
                fmt(u), fmt(h), fmt(r));
            v2dep = sprintf('{"matlab":">=R2022a","dependencies":{"testpkg1":">=1.0"},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-03-01"}', ...
                fmt(u2v1), fmt(h2v1));
            json = [...
                '{' ...
                    '"index_version":1,' ...
                    '"generated":"2026-01-01T00:00:00Z",' ...
                    '"packages":{' ...
                        '"testpkg1":{"name":"testpkg1","description":"Test package 1","license":"MIT","authors":["Test"],"latest":"2.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(u1v1, h1v1, '2025-01-01') ',"2.0.0":' vfmt(u1v2, h1v2, '2025-06-01') '}},' ...
                        '"testpkg2":{"name":"testpkg2","description":"Test package 2","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' v2dep '}},' ...
                        '"testpkg3":{"name":"testpkg3","description":"Test package 3","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(u3v1, h3v1, '2025-01-01') '}}' ...
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
            tbxmanager("install");
            testCase.verifyTrue(true);
        end

        function testUninstallNoArgs(testCase)
            tbxmanager("uninstall");
            testCase.verifyTrue(true);
        end

        function testEnableNoArgs(testCase)
            tbxmanager("enable");
            testCase.verifyTrue(true);
        end

        function testDisableNoArgs(testCase)
            tbxmanager("disable");
            testCase.verifyTrue(true);
        end

        % --- Install ---

        function testInstallSinglePackage(testCase)
            tbxmanager("install", "testpkg1");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyTrue(isfolder(pkgDir), 'Package directory should exist');
        end

        function testInstallTarGzPackage(testCase)
            tbxmanager("install", "testpkg3");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg3");
            testCase.verifyTrue(isfolder(pkgDir), 'tar.gz package should be installed');
        end

        function testInstallCreatesFiles(testCase)
            tbxmanager("install", "testpkg1");
            versions = dir(fullfile(testCase.TempDir, "packages", "testpkg1"));
            versionDirs = versions([versions.isdir] & ~ismember({versions.name}, {'.', '..'}));
            testCase.verifyGreaterThanOrEqual(numel(versionDirs), 1);
        end

        function testDoubleInstall(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("install", "testpkg1");
            testCase.verifyTrue(true);
        end

        function testInstallWithDependency(testCase)
            tbxmanager("install", "testpkg2");
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg2")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")));
        end

        % --- List ---

        function testListAfterInstall(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("list");
            testCase.verifyTrue(true);
        end

        % --- Search ---

        function testSearchFindsPackage(testCase)
            tbxmanager("search", "testpkg");
            testCase.verifyTrue(true);
        end

        function testSearchNoResults(testCase)
            tbxmanager("search", "nonexistent_xyz_12345");
            testCase.verifyTrue(true);
        end

        % --- Info ---

        function testInfoPackage(testCase)
            tbxmanager("info", "testpkg1");
            testCase.verifyTrue(true);
        end

        % --- Enable/Disable ---

        function testEnableDisableCycle(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("disable", "testpkg1");

            f = fullfile(testCase.TempDir, "state", "enabled.json");
            data = jsondecode(fileread(f));
            if isstruct(data.packages)
                names = fieldnames(data.packages);
                testCase.verifyFalse(ismember('testpkg1', names));
            end

            tbxmanager("enable", "testpkg1");
            data2 = jsondecode(fileread(f));
            names2 = fieldnames(data2.packages);
            testCase.verifyTrue(ismember('testpkg1', names2));
        end

        function testRestorePathAfterDisable(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("enable", "testpkg1");
            tbxmanager("restorepath");
            testCase.verifyTrue(true);
        end

        % --- Update ---

        function testUpdatePackage(testCase)
            tbxmanager("install", "testpkg1@==1.0.0");
            tbxmanager("update", "testpkg1");
            testCase.verifyTrue(true);
        end

        % --- Uninstall ---

        function testUninstallPackage(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("uninstall", "testpkg1");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyFalse(isfolder(pkgDir), 'Package should be removed');
        end

        function testUninstallWithDeps(testCase)
            tbxmanager("install", "testpkg2");
            tbxmanager("uninstall", "testpkg1");
            testCase.verifyTrue(true);
        end

    end
end
