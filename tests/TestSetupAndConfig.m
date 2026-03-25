classdef TestSetupAndConfig < matlab.unittest.TestCase
    % Tests for setup, config, base directory, and platform detection.

    properties
        TempDir
        OrigHome
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            setenv("TBXMANAGER_HOME", testCase.TempDir);
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)

        function testSetupCreatesDirectories(testCase)
            tbxmanager("help");
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "cache")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "state")));
        end

        function testSetupCreatesSourcesJson(testCase)
            tbxmanager("help");
            f = fullfile(testCase.TempDir, "state", "sources.json");
            testCase.verifyTrue(isfile(f));
            data = jsondecode(fileread(f));
            testCase.verifyTrue(iscell(data.sources) || isstring(data.sources));
        end

        function testSetupCreatesEnabledJson(testCase)
            tbxmanager("help");
            f = fullfile(testCase.TempDir, "state", "enabled.json");
            testCase.verifyTrue(isfile(f));
            data = jsondecode(fileread(f));
            testCase.verifyTrue(isstruct(data.packages));
        end

        function testBaseDirRespectsEnvVar(testCase)
            tbxmanager("internal__", "baseDir");
            testCase.verifyEqual(string(ans), string(testCase.TempDir));
        end

        function testPlatformArchReturnsValid(testCase)
            tbxmanager("internal__", "platformArch");
            valid = ["win64", "maci64", "maca64", "glnxa64"];
            testCase.verifyTrue(ismember(string(ans), valid));
        end

        function testConfigCreated(testCase)
            tbxmanager("help");
            f = fullfile(testCase.TempDir, "config.json");
            testCase.verifyTrue(isfile(f));
        end

    end
end
