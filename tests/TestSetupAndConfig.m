classdef TestSetupAndConfig < matlab.unittest.TestCase
    % Tests for setup, config, base directory, and platform detection.

    properties
        TempDir
        OrigHome
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            mkdir(testCase.TempDir);
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            setenv("TBXMANAGER_HOME", testCase.TempDir);
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)

        function testSetupCreatesDirectories(testCase)
            evalc('tbxmanager("help")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "cache")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "state")));
        end

        function testSetupCreatesSourcesJson(testCase)
            evalc('tbxmanager("help")');
            f = fullfile(testCase.TempDir, "state", "sources.json");
            testCase.verifyTrue(isfile(f));
            data = jsondecode(fileread(f));
            testCase.verifyTrue(iscell(data.sources) || isstring(data.sources));
        end

        function testSetupCreatesEnabledJson(testCase)
            evalc('tbxmanager("help")');
            f = fullfile(testCase.TempDir, "state", "enabled.json");
            testCase.verifyTrue(isfile(f));
            data = jsondecode(fileread(f));
            testCase.verifyTrue(isstruct(data.packages));
        end

        function testBaseDirRespectsEnvVar(testCase)
            evalc('result = tbxmanager("internal__", "baseDir")');
            testCase.verifyEqual(string(result), string(testCase.TempDir));
        end

        function testPlatformArchReturnsValid(testCase)
            evalc('result = tbxmanager("internal__", "platformArch")');
            valid = ["win64", "maci64", "maca64", "glnxa64"];
            testCase.verifyTrue(ismember(string(result), valid));
        end

        function testPlatformArchIsCached(testCase)
            evalc('r1 = tbxmanager("internal__", "platformArch")');
            evalc('r2 = tbxmanager("internal__", "platformArch")');
            testCase.verifyEqual(string(r1), string(r2), ...
                'Consecutive calls should return identical cached result');
        end

        function testConfigCreated(testCase)
            evalc('tbxmanager("help")');
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "state")));
        end

    end
end
