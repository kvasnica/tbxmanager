classdef TestLockSync < matlab.unittest.TestCase
    % Tests for lock and sync commands with mock packages.

    properties
        TempDir
        OrigHome
        OrigDir
        OrigPath
        MockIndexFile
        MockPkgDir
        ProjectDir
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            mkdir(testCase.TempDir);
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            testCase.OrigPath = path;
            setenv("TBXMANAGER_HOME", testCase.TempDir);

            % Ensure tbxmanager stays on path after cd
            tbxFile = which("tbxmanager");
            if ~isempty(tbxFile)
                addpath(fileparts(tbxFile));
            end

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

            % Create project directory with tbxmanager.json
            testCase.ProjectDir = fullfile(testCase.TempDir, "project");
            mkdir(testCase.ProjectDir);
            projData = struct();
            projData.name = 'myproject';
            projData.version = '0.1.0';
            projData.dependencies = struct('testpkg2', '>=1.0');
            fid = fopen(fullfile(testCase.ProjectDir, "tbxmanager.json"), 'w');
            fprintf(fid, '%s', jsonencode(projData));
            fclose(fid);

            % Teardowns run LIFO
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

            % Create testpkg2 v2.0.0 (depends on testpkg1)
            d2 = fullfile(testCase.MockPkgDir, "testpkg2_v2");
            mkdir(d2);
            fid = fopen(fullfile(d2, "testpkg2_hello.m"), 'w');
            fprintf(fid, 'function testpkg2_hello()\ndisp(''hello from testpkg2 v2'');\nend\n');
            fclose(fid);
            zip(fullfile(testCase.MockPkgDir, "testpkg2-2.0.0-all.zip"), '*', d2);
        end

        function hash = computeSha256(~, filepath)
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

        function s = jsonEscape(~, s0)
            s = char(s0);
            s = strrep(s, '\', '\\');
            s = strrep(s, '"', '\"');
        end

        function createMockIndex(testCase)
            d = testCase.MockPkgDir;

            h1v1 = testCase.computeSha256(fullfile(d, "testpkg1-1.0.0-all.zip"));
            h2v2 = testCase.computeSha256(fullfile(d, "testpkg2-2.0.0-all.zip"));

            u1v1 = char("file://" + replace(string(fullfile(d, "testpkg1-1.0.0-all.zip")), "\", "/"));
            u2v2 = char("file://" + replace(string(fullfile(d, "testpkg2-2.0.0-all.zip")), "\", "/"));

            fmt = @(s) strrep(testCase.jsonEscape(s), '%', '%%');
            vfmt = @(u,h,r) sprintf('{"matlab":">=R2022a","dependencies":{},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"%s"}', ...
                fmt(u), fmt(h), fmt(r));
            v2dep = sprintf('{"matlab":">=R2022a","dependencies":{"testpkg1":">=1.0"},"platforms":{"all":{"url":"%s","sha256":"%s"}},"released":"2025-03-01"}', ...
                fmt(u2v2), fmt(h2v2));

            json = [...
                '{' ...
                    '"index_version":1,' ...
                    '"generated":"2026-01-01T00:00:00Z",' ...
                    '"packages":{' ...
                        '"testpkg1":{"name":"testpkg1","description":"Test package 1","license":"MIT","authors":["Test"],"latest":"1.0.0",' ...
                        '"versions":{"1.0.0":' vfmt(u1v1, h1v1, '2025-01-01') '}},' ...
                        '"testpkg2":{"name":"testpkg2","description":"Test package 2","license":"MIT","authors":["Test"],"latest":"2.0.0",' ...
                        '"versions":{"2.0.0":' v2dep '}}' ...
                    '}' ...
                '}'];

            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '%s', json);
            fclose(fid);
        end
    end

    methods (Test)

        % --- lock errors ---

        function testLockNoProjectFile(testCase)
            emptyDir = fullfile(testCase.TempDir, "empty_project");
            mkdir(emptyDir);
            cd(emptyDir);
            out = evalc('tbxmanager("lock")');
            testCase.verifyTrue(contains(out, "tbxmanager.json") || contains(out, "No"), ...
                'Should report missing project file');
        end

        function testLockCreatesLockFile(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            lockFile = fullfile(testCase.ProjectDir, "tbxmanager.lock");
            testCase.verifyTrue(isfile(lockFile), 'Lock file should be created');
        end

        function testLockResolvesPackage(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            lockFile = fullfile(testCase.ProjectDir, "tbxmanager.lock");
            lockData = jsondecode(fileread(lockFile));
            testCase.verifyTrue(isfield(lockData, 'packages'), 'Lock should have packages field');
            testCase.verifyTrue(isfield(lockData.packages, 'testpkg2'), ...
                'Lock should contain testpkg2');
        end

        function testLockResolvesWithDeps(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            lockFile = fullfile(testCase.ProjectDir, "tbxmanager.lock");
            lockData = jsondecode(fileread(lockFile));
            testCase.verifyTrue(isfield(lockData.packages, 'testpkg1'), ...
                'Lock should contain dependency testpkg1');
            testCase.verifyTrue(isfield(lockData.packages, 'testpkg2'), ...
                'Lock should contain testpkg2');
        end

        function testLockContainsSha256(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            lockFile = fullfile(testCase.ProjectDir, "tbxmanager.lock");
            lockData = jsondecode(fileread(lockFile));
            pkg = lockData.packages.testpkg2;
            testCase.verifyTrue(isfield(pkg, 'resolved') && isfield(pkg.resolved, 'sha256'), ...
                'Lock entry should have sha256');
            testCase.verifyEqual(strlength(string(pkg.resolved.sha256)), 64, ...
                'SHA256 should be 64 hex characters');
        end

        function testLockContainsUrl(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            lockFile = fullfile(testCase.ProjectDir, "tbxmanager.lock");
            lockData = jsondecode(fileread(lockFile));
            pkg = lockData.packages.testpkg2;
            testCase.verifyTrue(isfield(pkg, 'resolved') && isfield(pkg.resolved, 'url'), ...
                'Lock entry should have url');
            testCase.verifyTrue(strlength(string(pkg.resolved.url)) > 0, ...
                'URL should not be empty');
        end

        % --- sync errors ---

        function testSyncNoLockFile(testCase)
            emptyDir = fullfile(testCase.TempDir, "empty_sync");
            mkdir(emptyDir);
            cd(emptyDir);
            out = evalc('tbxmanager("sync")');
            testCase.verifyTrue(contains(out, "lock") || contains(out, "No"), ...
                'Should report missing lock file');
        end

        function testSyncInstallsFromLock(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            evalc('tbxmanager("sync")');
            testCase.verifyTrue( ...
                isfolder(fullfile(testCase.TempDir, "packages", "testpkg2")), ...
                'testpkg2 should be installed after sync');
            testCase.verifyTrue( ...
                isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")), ...
                'testpkg1 (dependency) should be installed after sync');
        end

        function testSyncSkipsUpToDate(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            evalc('tbxmanager("sync")');
            out = evalc('tbxmanager("sync")');
            testCase.verifyTrue(contains(out, "up to date"), ...
                'Second sync should report up to date');
        end

        function testLockThenSyncRoundtrip(testCase)
            cd(testCase.ProjectDir);
            evalc('tbxmanager("lock")');
            evalc('tbxmanager("sync")');
            out = evalc('tbxmanager("list")');
            testCase.verifyTrue(contains(out, "testpkg2"), ...
                'List should show testpkg2 after lock+sync');
            testCase.verifyTrue(contains(out, "testpkg1"), ...
                'List should show testpkg1 after lock+sync');
        end

    end
end
