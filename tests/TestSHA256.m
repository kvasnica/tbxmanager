classdef TestSHA256 < matlab.unittest.TestCase
    % Test SHA256 hash computation.

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

        function testKnownHash(testCase)
            f = fullfile(testCase.TempDir, "testfile.txt");
            fid = fopen(f, 'w');
            fprintf(fid, 'hello\n');
            fclose(fid);
            hash = tbxmanager("internal__", "sha256", f);
            hash = string(hash);
            testCase.verifyEqual(strlength(hash), 64);
            testCase.verifyTrue(all(isstrprop(char(hash), 'xdigit')));
        end

        function testDifferentFilesHaveDifferentHashes(testCase)
            f1 = fullfile(testCase.TempDir, "file1.txt");
            f2 = fullfile(testCase.TempDir, "file2.txt");
            fid = fopen(f1, 'w'); fprintf(fid, 'aaa'); fclose(fid);
            fid = fopen(f2, 'w'); fprintf(fid, 'bbb'); fclose(fid);
            h1 = string(tbxmanager("internal__", "sha256", f1));
            h2 = string(tbxmanager("internal__", "sha256", f2));
            testCase.verifyNotEqual(h1, h2);
        end

        function testSameFileGivesSameHash(testCase)
            f = fullfile(testCase.TempDir, "same.txt");
            fid = fopen(f, 'w'); fprintf(fid, 'test content'); fclose(fid);
            h1 = string(tbxmanager("internal__", "sha256", f));
            h2 = string(tbxmanager("internal__", "sha256", f));
            testCase.verifyEqual(h1, h2);
        end

    end
end
