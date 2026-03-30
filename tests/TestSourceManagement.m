classdef TestSourceManagement < matlab.unittest.TestCase
    % Tests for source add/remove/list operations.

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

        function testDefaultSourceExists(testCase)
            evalc('tbxmanager("help")');
            f = fullfile(testCase.TempDir, "state", "sources.json");
            data = jsondecode(fileread(f));
            sources = string(data.sources);
            testCase.verifyTrue(any(contains(sources, "tbxmanager-registry")));
        end

        function testAddSource(testCase)
            evalc('tbxmanager("help")');
            evalc('tbxmanager("source", "add", "https://example.com/custom/index.json")');
            f = fullfile(testCase.TempDir, "state", "sources.json");
            data = jsondecode(fileread(f));
            sources = string(data.sources);
            testCase.verifyTrue(any(sources == "https://example.com/custom/index.json"));
        end

        function testRemoveSource(testCase)
            evalc('tbxmanager("help")');
            evalc('tbxmanager("source", "add", "https://example.com/temp.json")');
            evalc('tbxmanager("source", "remove", "https://example.com/temp.json")');
            f = fullfile(testCase.TempDir, "state", "sources.json");
            data = jsondecode(fileread(f));
            sources = string(data.sources);
            testCase.verifyFalse(any(sources == "https://example.com/temp.json"));
        end

        function testDuplicateSourceNotAdded(testCase)
            evalc('tbxmanager("help")');
            evalc('tbxmanager("source", "add", "https://example.com/dup.json")');
            evalc('tbxmanager("source", "add", "https://example.com/dup.json")');
            f = fullfile(testCase.TempDir, "state", "sources.json");
            data = jsondecode(fileread(f));
            sources = string(data.sources);
            count = sum(sources == "https://example.com/dup.json");
            testCase.verifyEqual(count, 1);
        end

    end
end
