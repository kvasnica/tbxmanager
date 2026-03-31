classdef TestInternal < matlab.unittest.TestCase
    % Tests for the internal__ dispatch mechanism that exposes internal
    % functions for testing.

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

            % Initialize tbxmanager
            evalc('tbxmanager("help")');

            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
        end
    end

    methods (Test)

        % --- parseVersion ---

        function testInternalParseVersion(testCase)
            result = tbxmanager("internal__", "parseVersion", "1.2.3");
            testCase.verifyEqual(result, [1 2 3], ...
                'parseVersion("1.2.3") should return [1 2 3]');
        end

        function testInternalParseVersionTwoPart(testCase)
            result = tbxmanager("internal__", "parseVersion", "3.7");
            testCase.verifyEqual(result, [3 7 0], ...
                'parseVersion("3.7") should return [3 7 0]');
        end

        % --- sha256 ---

        function testInternalSha256(testCase)
            tmpFile = fullfile(testCase.TempDir, "hashtest.txt");
            fid = fopen(tmpFile, 'w');
            fprintf(fid, 'hello world');
            fclose(fid);
            result = tbxmanager("internal__", "sha256", tmpFile);
            testCase.verifyTrue(ischar(result) || isstring(result), ...
                'sha256 should return a string');
            testCase.verifyEqual(strlength(string(result)), 64, ...
                'SHA256 hash should be 64 hex characters');
        end

        function testInternalSha256Deterministic(testCase)
            tmpFile = fullfile(testCase.TempDir, "hashdet.txt");
            fid = fopen(tmpFile, 'w');
            fprintf(fid, 'deterministic test content');
            fclose(fid);
            result1 = tbxmanager("internal__", "sha256", tmpFile);
            result2 = tbxmanager("internal__", "sha256", tmpFile);
            testCase.verifyEqual(string(result1), string(result2), ...
                'Same file should produce same hash');
        end

        % --- baseDir ---

        function testInternalBaseDir(testCase)
            result = tbxmanager("internal__", "baseDir");
            testCase.verifyTrue(ischar(result) || isstring(result), ...
                'baseDir should return a string');
            testCase.verifyTrue(strlength(string(result)) > 0, ...
                'baseDir should not be empty');
            testCase.verifyTrue(isfolder(result), ...
                'baseDir should be an existing directory');
        end

        % --- platformArch ---

        function testInternalPlatformArch(testCase)
            result = tbxmanager("internal__", "platformArch");
            validPlatforms = ["win64", "maci64", "maca64", "glnxa64"];
            testCase.verifyTrue(ismember(string(result), validPlatforms), ...
                'platformArch should return a known platform');
        end

        % --- unknown function ---

        function testInternalUnknownFunction(testCase)
            testCase.verifyError( ...
                @() tbxmanager("internal__", "nonexistent_func_xyz"), ...
                'TBXMANAGER:Internal');
        end

        % --- no arguments ---

        function testInternalNoArgs(testCase)
            testCase.verifyError( ...
                @() tbxmanager("internal__"), ...
                'TBXMANAGER:Internal');
        end

        % --- compareVersions ---

        function testInternalCompareVersions(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.0.0", "2.0.0");
            testCase.verifyEqual(result, -1, '1.0.0 should be less than 2.0.0');
        end

        function testInternalCompareVersionsEqual(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.2.3", "1.2.3");
            testCase.verifyEqual(result, 0, 'Same versions should be equal');
        end

        function testInternalCompareVersionsGreater(testCase)
            result = tbxmanager("internal__", "compareVersions", "3.0.0", "1.0.0");
            testCase.verifyEqual(result, 1, '3.0.0 should be greater than 1.0.0');
        end

        % --- satisfiesConstraint ---

        function testInternalSatisfiesConstraint(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.5.0", ">=1.0");
            testCase.verifyTrue(logical(result), '1.5.0 should satisfy >=1.0');
        end

        function testInternalSatisfiesConstraintFails(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "0.9.0", ">=1.0");
            testCase.verifyFalse(logical(result), '0.9.0 should not satisfy >=1.0');
        end

        function testInternalSatisfiesConstraintWildcard(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "99.0.0", "*");
            testCase.verifyTrue(logical(result), 'Any version should satisfy wildcard');
        end

        % --- listInstalled ---

        function testInternalListInstalledEmpty(testCase)
            result = tbxmanager("internal__", "listInstalled");
            testCase.verifyTrue(isempty(result), ...
                'listInstalled should be empty with no packages');
        end

        % --- readJson / writeJson ---

        function testInternalReadWriteJson(testCase)
            jsonFile = fullfile(testCase.TempDir, "test_rw.json");
            data = struct("key1", "value1", "key2", 42);
            evalc('tbxmanager("internal__", "writeJson", jsonFile, jsonencode(data))');
            testCase.verifyTrue(isfile(jsonFile), 'JSON file should exist');

            result = tbxmanager("internal__", "readJson", jsonFile);
            testCase.verifyEqual(string(result.key1), "value1");
            testCase.verifyEqual(result.key2, 42);
        end

    end
end
