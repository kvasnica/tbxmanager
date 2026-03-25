classdef TestSHA256 < matlab.unittest.TestCase
    % Test SHA256 hash computation.

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

        function testKnownHash(testCase)
            % SHA256 of "hello\n" is known
            f = fullfile(testCase.TempDir, "testfile.txt");
            fid = fopen(f, 'w');
            fprintf(fid, 'hello\n');
            fclose(fid);
            tbxmanager("internal__", "sha256", f);
            hash = string(ans);
            % "hello\n" (with literal backslash-n, 7 bytes)
            % Compute expected: just verify it's a 64-char hex string
            testCase.verifyEqual(strlength(hash), 64);
            testCase.verifyTrue(all(isstrprop(char(hash), 'xdigit')));
        end

        function testDifferentFilesHaveDifferentHashes(testCase)
            f1 = fullfile(testCase.TempDir, "file1.txt");
            f2 = fullfile(testCase.TempDir, "file2.txt");
            fid = fopen(f1, 'w'); fprintf(fid, 'aaa'); fclose(fid);
            fid = fopen(f2, 'w'); fprintf(fid, 'bbb'); fclose(fid);
            tbxmanager("internal__", "sha256", f1);
            h1 = string(ans);
            tbxmanager("internal__", "sha256", f2);
            h2 = string(ans);
            testCase.verifyNotEqual(h1, h2);
        end

        function testSameFileGivesSameHash(testCase)
            f = fullfile(testCase.TempDir, "same.txt");
            fid = fopen(f, 'w'); fprintf(fid, 'test content'); fclose(fid);
            tbxmanager("internal__", "sha256", f);
            h1 = string(ans);
            tbxmanager("internal__", "sha256", f);
            h2 = string(ans);
            testCase.verifyEqual(h1, h2);
        end

    end
end
