classdef TestCommands < matlab.unittest.TestCase
    % Tests for user-facing commands (help, list, source, init, cache, require, etc.).
    % These tests run without network access — they test offline behavior.

    properties
        TempDir
        OrigHome
        OrigDir
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            mkdir(testCase.TempDir);
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            setenv("TBXMANAGER_HOME", testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
        end
    end

    methods (Test)

        % --- help ---

        function testHelpRuns(testCase)
            out = evalc('tbxmanager("help")');
            testCase.verifyNotEmpty(out);
        end

        function testHelpInstall(testCase)
            out = evalc('tbxmanager("help", "install")');
            testCase.verifyNotEmpty(out);
        end

        function testHelpAllCommands(testCase)
            cmds = ["install","uninstall","update","list","search","info",...
                    "lock","sync","init","selfupdate","source","enable",...
                    "disable","restorepath","require","cache","publish"];
            for i = 1:numel(cmds)
                evalc('tbxmanager("help", cmds(i))');
            end
            testCase.verifyTrue(true);
        end

        function testNoArgsRunsHelp(testCase)
            out = evalc('tbxmanager()');
            testCase.verifyNotEmpty(out);
        end

        % --- list (empty) ---

        function testListEmpty(testCase)
            evalc('tbxmanager("list")');
            testCase.verifyTrue(true);
        end

        % --- source ---

        function testSourceList(testCase)
            evalc('tbxmanager("source", "list")');
            testCase.verifyTrue(true);
        end

        function testSourceAddRemove(testCase)
            evalc('tbxmanager("source", "add", "https://example.com/index.json")');
            evalc('tbxmanager("source", "list")');
            evalc('tbxmanager("source", "remove", "https://example.com/index.json")');
            testCase.verifyTrue(true);
        end

        % --- init ---

        function testInit(testCase)
            workDir = fullfile(testCase.TempDir, "project");
            mkdir(workDir);
            cd(workDir);
            evalc('tbxmanager("init")');
            testCase.verifyTrue(isfile(fullfile(workDir, "tbxmanager.json")));
            data = jsondecode(fileread(fullfile(workDir, "tbxmanager.json")));
            testCase.verifyTrue(isfield(data, 'name'));
            testCase.verifyTrue(isfield(data, 'dependencies'));
        end

        function testInitExistingFileHeadless(testCase)
            % When tbxmanager.json already exists and MATLAB is in headless mode
            % (usejava('desktop') == false in CI), the warning is printed and we return.
            workDir = fullfile(testCase.TempDir, "proj_existing");
            mkdir(workDir);
            cd(workDir);
            evalc('tbxmanager("init")');
            % Run init again — should warn and return without overwriting
            out = evalc('tbxmanager("init")');
            testCase.verifyTrue(contains(out, "already exists"), ...
                'Should warn that tbxmanager.json already exists');
        end

        % --- source edge cases ---

        function testSourceNoArgs(testCase)
            % No args defaults to "list"
            evalc('tbxmanager("source")');
            testCase.verifyTrue(true);
        end

        function testSourceAddNoUrl(testCase)
            out = evalc('tbxmanager("source", "add")');
            testCase.verifyTrue(contains(out, "Usage"), ...
                'Should print usage when no URL given');
        end

        function testSourceRemoveNoUrl(testCase)
            out = evalc('tbxmanager("source", "remove")');
            testCase.verifyTrue(contains(out, "Usage"), ...
                'Should print usage when no URL given');
        end

        function testSourceUnknownSubCmd(testCase)
            out = evalc('tbxmanager("source", "foobar")');
            testCase.verifyTrue(contains(out, "Unknown") || contains(out, "foobar"), ...
                'Should report unknown sub-command');
        end

        function testSourceListEmpty(testCase)
            % Manually write an empty sources array to hit "No sources configured" branch
            evalc('tbxmanager("help")');
            stateDir = fullfile(testCase.TempDir, "state");
            fid = fopen(fullfile(stateDir, "sources.json"), 'w');
            fprintf(fid, '{"sources":[]}');
            fclose(fid);
            out = evalc('tbxmanager("source", "list")');
            testCase.verifyTrue(contains(out, "No sources"), ...
                'Should report no sources when sources array is empty');
        end

        % --- cache ---

        function testCacheNoArgs(testCase)
            % No args defaults to "list"
            evalc('tbxmanager("cache")');
            testCase.verifyTrue(true);
        end

        function testCacheListEmpty(testCase)
            % No cache dir — should print empty message
            out = evalc('tbxmanager("cache", "list")');
            testCase.verifyTrue(contains(out, "empty") || contains(out, "Cache"), ...
                'Should report empty cache');
        end

        function testCacheListWithFiles(testCase)
            % Create cache dir with a file, then list
            evalc('tbxmanager("help")');
            cacheDir = fullfile(testCase.TempDir, "cache");
            fid = fopen(fullfile(cacheDir, "pkg-1.0.0-all.zip"), 'w');
            fwrite(fid, repmat('x', 1, 1500));  % 1500 bytes (KB range)
            fclose(fid);
            out = evalc('tbxmanager("cache", "list")');
            testCase.verifyTrue(contains(out, "pkg-1.0.0-all.zip"), ...
                'Should list the cached file');
        end

        function testCacheCleanNoCacheDir(testCase)
            % Cache dir doesn't exist yet
            out = evalc('tbxmanager("cache", "clean")');
            testCase.verifyTrue(contains(out, "does not exist") || contains(out, "Cleaned"), ...
                'Should handle missing cache dir gracefully');
        end

        function testCacheClean(testCase)
            % Ensure setup has run so cache dir exists
            evalc('tbxmanager("help")');
            cacheDir = fullfile(testCase.TempDir, "cache");
            fid = fopen(fullfile(cacheDir, "test-1.0.0-all.zip"), 'w');
            fwrite(fid, 'fake');
            fclose(fid);
            evalc('tbxmanager("cache", "clean")');
            files = dir(fullfile(cacheDir, "*.zip"));
            testCase.verifyEmpty(files);
        end

        function testCacheUnknownSubCmd(testCase)
            out = evalc('tbxmanager("cache", "foobar")');
            testCase.verifyTrue(contains(out, "Unknown") || contains(out, "foobar"), ...
                'Should report unknown sub-command');
        end

        % --- search / info (no args) ---

        function testSearchNoArgs(testCase)
            out = evalc('tbxmanager("search")');
            testCase.verifyTrue(contains(out, "Usage"), ...
                'Should print usage when no query given');
        end

        function testInfoNoArgs(testCase)
            out = evalc('tbxmanager("info")');
            testCase.verifyTrue(contains(out, "Usage"), ...
                'Should print usage when no package given');
        end

        % --- unknown command ---

        function testUnknownCommand(testCase)
            evalc('tbxmanager("notacommand")');
            testCase.verifyTrue(true);
        end

        % --- enable/disable without packages ---

        function testEnableNonexistent(testCase)
            evalc('tbxmanager("enable", "nonexistent_pkg_xyz")');
            testCase.verifyTrue(true);
        end

        % --- require ---

        function testRequireNoArgs(testCase)
            out = evalc('tbxmanager("require")');
            testCase.verifyTrue(contains(out, "Usage"), ...
                'Should print usage when no args given');
        end

        function testRequireMissing(testCase)
            testCase.verifyError(...
                @() tbxmanager("require", "nonexistent_pkg_xyz"), ...
                'TBXMANAGER:RequireMissing');
        end

        function testRequireWithConstraint(testCase)
            % Package not enabled — should still throw RequireMissing
            testCase.verifyError(...
                @() tbxmanager("require", "nonexistent_pkg_xyz@>=1.0"), ...
                'TBXMANAGER:RequireMissing');
        end

        function testRequireVersionMismatch(testCase)
            % Manually write enabled.json with testpkg at 1.0.0, then require >=2.0
            evalc('tbxmanager("help")');
            stateDir = fullfile(testCase.TempDir, "state");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg_req", "1.0.0");
            mkdir(pkgDir);
            pkgEntry.version = "1.0.0";
            pkgEntry.path = pkgDir;
            pkgs.testpkg_req = pkgEntry;
            data.packages = pkgs;
            fid = fopen(fullfile(stateDir, "enabled.json"), 'w');
            fprintf(fid, '%s', jsonencode(data));
            fclose(fid);
            testCase.verifyError(...
                @() tbxmanager("require", "testpkg-req@>=2.0"), ...
                'TBXMANAGER:RequireVersionMismatch');
        end

        % --- restorepath ---

        function testRestorepathEmpty(testCase)
            evalc('tbxmanager("restorepath")');
            testCase.verifyTrue(true);
        end

        function testRestorepathMissingDir(testCase)
            % enabled.json points to non-existent path — should warn (to stderr) but not crash
            evalc('tbxmanager("help")');
            stateDir = fullfile(testCase.TempDir, "state");
            pkgEntry.version = "1.0.0";
            pkgEntry.path = fullfile(testCase.TempDir, "nonexistent", "path");
            pkgs.ghost_pkg = pkgEntry;
            data.packages = pkgs;
            fid = fopen(fullfile(stateDir, "enabled.json"), 'w');
            fprintf(fid, '%s', jsonencode(data));
            fclose(fid);
            % Warning goes to stderr; evalc captures stdout only.
            % Just verify no exception is thrown.
            evalc('tbxmanager("restorepath")');
            testCase.verifyTrue(true, 'restorepath with missing dir should not throw');
        end

    end
end
