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
                    "disable","restorepath","require","cache"];
            for i = 1:numel(cmds)
                evalc('tbxmanager("help", cmds(i))');
            end
            testCase.verifyTrue(true);
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

        % --- cache ---

        function testCacheList(testCase)
            evalc('tbxmanager("cache", "list")');
            testCase.verifyTrue(true);
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

        % --- require missing ---

        function testRequireMissing(testCase)
            testCase.verifyError(...
                @() tbxmanager("require", "nonexistent_pkg_xyz"), ...
                'TBXMANAGER:RequireMissing');
        end

        % --- restorepath (empty) ---

        function testRestorepathEmpty(testCase)
            evalc('tbxmanager("restorepath")');
            testCase.verifyTrue(true);
        end

    end
end
