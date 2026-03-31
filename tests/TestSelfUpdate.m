classdef TestSelfUpdate < matlab.unittest.TestCase
    % Tests for selfupdate command. Uses file:// URLs to avoid network.
    % IMPORTANT: Does NOT test actual file replacement to avoid destroying
    % the real tbxmanager.m during test runs.

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

            % Initialize tbxmanager so config dir exists
            evalc('tbxmanager("help")');

            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
        end
    end

    methods (Access = private)
        function setConfig(testCase, cfg)
            cfgFile = fullfile(testCase.TempDir, "config.json");
            fid = fopen(cfgFile, 'w');
            fprintf(fid, '%s', jsonencode(cfg));
            fclose(fid);
        end
    end

    methods (Test)

        function testSelfUpdateAlreadyUpToDate(testCase)
            % Point selfupdate_url to a copy of the current tbxmanager.m.
            % Same content = same hash = "up to date" — safe, no overwrite.
            currentFile = string(which("tbxmanager"));
            copyPath = fullfile(testCase.TempDir, "tbxmanager_copy.m");
            copyfile(char(currentFile), copyPath);
            copyUrl = "file://" + replace(string(copyPath), "\", "/");

            cfg = struct("selfupdate_url", char(copyUrl));
            testCase.setConfig(cfg);

            out = evalc('tbxmanager("selfupdate")');
            testCase.verifyTrue(contains(out, "up to date"), ...
                'Should report already up to date when hash matches');
        end

        function testSelfUpdateBadUrl(testCase)
            % Point to a non-existent file
            badPath = fullfile(testCase.TempDir, "nonexistent_file.m");
            badUrl = "file://" + replace(string(badPath), "\", "/");

            cfg = struct("selfupdate_url", char(badUrl));
            testCase.setConfig(cfg);

            out = evalc('tbxmanager("selfupdate")');
            testCase.verifyTrue( ...
                contains(out, "Failed") || contains(out, "Error") || contains(out, "error"), ...
                'Should report error for bad URL');
        end

    end
end
