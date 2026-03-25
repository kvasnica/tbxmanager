classdef TestCommands < matlab.unittest.TestCase
    % Tests for user-facing commands (help, list, source, init, cache).
    % These tests run without network access — they test offline behavior.

    properties
        TempDir
        OrigHome
        OrigDir
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            setenv("TBXMANAGER_HOME", testCase.TempDir);
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)

        % --- help ---

        function testHelpRuns(testCase)
            tbxmanager("help");
            % Should not error
            testCase.verifyTrue(true);
        end

        function testHelpInstall(testCase)
            tbxmanager("help", "install");
            testCase.verifyTrue(true);
        end

        function testHelpAllCommands(testCase)
            cmds = ["install","uninstall","update","list","search","info",...
                    "lock","sync","init","selfupdate","source","enable",...
                    "disable","restorepath","require","cache"];
            for i = 1:numel(cmds)
                tbxmanager("help", cmds(i));
            end
            testCase.verifyTrue(true);
        end

        % --- list (empty) ---

        function testListEmpty(testCase)
            tbxmanager("list");
            testCase.verifyTrue(true);
        end

        % --- source ---

        function testSourceList(testCase)
            tbxmanager("source", "list");
            testCase.verifyTrue(true);
        end

        function testSourceAddRemove(testCase)
            tbxmanager("source", "add", "https://example.com/index.json");
            tbxmanager("source", "list");
            tbxmanager("source", "remove", "https://example.com/index.json");
            testCase.verifyTrue(true);
        end

        % --- init ---

        function testInit(testCase)
            workDir = fullfile(testCase.TempDir, "project");
            mkdir(workDir);
            cd(workDir);
            tbxmanager("init");
            testCase.verifyTrue(isfile(fullfile(workDir, "tbxmanager.json")));
            data = jsondecode(fileread(fullfile(workDir, "tbxmanager.json")));
            testCase.verifyTrue(isfield(data, 'name'));
            testCase.verifyTrue(isfield(data, 'dependencies'));
        end

        % --- cache ---

        function testCacheList(testCase)
            tbxmanager("cache", "list");
            testCase.verifyTrue(true);
        end

        function testCacheClean(testCase)
            % Create a fake cache file
            cacheDir = fullfile(testCase.TempDir, "cache");
            fid = fopen(fullfile(cacheDir, "test-1.0.0-all.zip"), 'w');
            fwrite(fid, 'fake');
            fclose(fid);
            tbxmanager("cache", "clean");
            files = dir(fullfile(cacheDir, "*.zip"));
            testCase.verifyEmpty(files);
        end

        % --- unknown command ---

        function testUnknownCommand(testCase)
            % Should print error but not throw
            tbxmanager("notacommand");
            testCase.verifyTrue(true);
        end

        % --- enable/disable without packages ---

        function testEnableNonexistent(testCase)
            % Should handle gracefully
            tbxmanager("enable", "nonexistent_pkg_xyz");
            testCase.verifyTrue(true);
        end

        % --- require missing ---

        function testRequireMissing(testCase)
            testCase.verifyError(...
                @() tbxmanager("require", "nonexistent_pkg_xyz"), ...
                'TBXMANAGER:NotInstalled');
        end

        % --- restorepath (empty) ---

        function testRestorepathEmpty(testCase)
            tbxmanager("restorepath");
            testCase.verifyTrue(true);
        end

    end
end
