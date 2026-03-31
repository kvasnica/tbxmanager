classdef TestPublish < matlab.unittest.TestCase
    % Tests for publish command validation and archive building.
    % Does NOT make actual GitHub API calls.

    properties
        TempDir
        OrigHome
        OrigDir
        OrigPath
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            mkdir(testCase.TempDir);
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            testCase.OrigPath = path;
            setenv("TBXMANAGER_HOME", testCase.TempDir);

            % Ensure tbxmanager stays on path after cd
            tbxFile = which("tbxmanager");
            if ~isempty(tbxFile)
                addpath(fileparts(tbxFile));
            end

            % Initialize tbxmanager
            evalc('tbxmanager("help")');

            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() path(testCase.OrigPath));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
        end
    end

    methods (Access = private)
        function projectDir = createMockProject(testCase, pkgJson)
            % Create a mock project directory with given tbxmanager.json content,
            % some .m files, a .mat file, and a .git directory.
            projectDir = fullfile(testCase.TempDir, "project_" + string(randi(99999)));
            mkdir(projectDir);

            % Write tbxmanager.json
            fid = fopen(fullfile(projectDir, "tbxmanager.json"), 'w');
            fprintf(fid, '%s', jsonencode(pkgJson));
            fclose(fid);

            % Create .m files
            fid = fopen(fullfile(projectDir, "myfunc.m"), 'w');
            fprintf(fid, 'function myfunc()\ndisp(''hello'');\nend\n');
            fclose(fid);

            fid = fopen(fullfile(projectDir, "helper.m"), 'w');
            fprintf(fid, 'function helper()\ndisp(''helper'');\nend\n');
            fclose(fid);

            % Create .mat file
            fid = fopen(fullfile(projectDir, "data.mat"), 'w');
            fwrite(fid, uint8(zeros(1, 64)));
            fclose(fid);

            % Create .git directory with a dummy file
            gitDir = fullfile(projectDir, ".git");
            mkdir(gitDir);
            fid = fopen(fullfile(gitDir, "config"), 'w');
            fprintf(fid, '[core]\nrepositoryformatversion = 0\n');
            fclose(fid);
        end

        function pkg = validPkgJson(~)
            pkg = struct();
            pkg.name = 'testpkg';
            pkg.version = '1.0.0';
            pkg.description = 'A test package';
            platforms = struct('all', struct());
            pkg.platforms = platforms;
        end
    end

    methods (Test)

        % --- Validation errors ---

        function testPublishNoProjectFile(testCase)
            emptyDir = fullfile(testCase.TempDir, "empty_pub");
            mkdir(emptyDir);
            cd(emptyDir);
            out = evalc('tbxmanager("publish")');
            testCase.verifyTrue( ...
                contains(out, "tbxmanager.json") || contains(out, "No"), ...
                'Should report missing tbxmanager.json');
        end

        function testPublishMissingName(testCase)
            pkg = struct();
            pkg.version = '1.0.0';
            pkg.description = 'test';
            pkg.platforms = struct('all', struct());
            projectDir = fullfile(testCase.TempDir, "no_name");
            mkdir(projectDir);
            fid = fopen(fullfile(projectDir, "tbxmanager.json"), 'w');
            fprintf(fid, '%s', jsonencode(pkg));
            fclose(fid);
            cd(projectDir);
            out = evalc('tbxmanager("publish")');
            testCase.verifyTrue(contains(out, "name"), ...
                'Should report missing name field');
        end

        function testPublishMissingVersion(testCase)
            pkg = struct();
            pkg.name = 'testpkg';
            pkg.description = 'test';
            pkg.platforms = struct('all', struct());
            projectDir = fullfile(testCase.TempDir, "no_version");
            mkdir(projectDir);
            fid = fopen(fullfile(projectDir, "tbxmanager.json"), 'w');
            fprintf(fid, '%s', jsonencode(pkg));
            fclose(fid);
            cd(projectDir);
            out = evalc('tbxmanager("publish")');
            testCase.verifyTrue(contains(out, "version"), ...
                'Should report missing version field');
        end

        function testPublishMultiPlatformError(testCase)
            pkg = struct();
            pkg.name = 'testpkg';
            pkg.version = '1.0.0';
            pkg.description = 'test';
            pkg.platforms = struct('win64', struct(), 'maci64', struct());
            projectDir = fullfile(testCase.TempDir, "multi_plat");
            mkdir(projectDir);
            fid = fopen(fullfile(projectDir, "tbxmanager.json"), 'w');
            fprintf(fid, '%s', jsonencode(pkg));
            fclose(fid);
            cd(projectDir);
            out = evalc('tbxmanager("publish")');
            testCase.verifyTrue( ...
                contains(out, "not yet supported") || contains(out, "separately"), ...
                'Should report multi-platform not supported');
        end

        % --- buildArchive via internal__ ---

        function testBuildArchiveCreatesZip(testCase)
            pkg = testCase.validPkgJson();
            projectDir = testCase.createMockProject(pkg);
            cd(projectDir);
            archivePath = fullfile(testCase.TempDir, "test_archive.zip");
            evalc('tbxmanager("internal__", "buildArchive", archivePath, ".git")');
            testCase.verifyTrue(isfile(archivePath), 'Archive zip should be created');
        end

        function testBuildArchiveExcludesPatterns(testCase)
            pkg = testCase.validPkgJson();
            projectDir = testCase.createMockProject(pkg);
            cd(projectDir);
            archivePath = fullfile(testCase.TempDir, "test_excl.zip");
            evalc('tbxmanager("internal__", "buildArchive", archivePath, ".git")');

            % List files in the zip
            outDir = fullfile(testCase.TempDir, "unzipped_excl");
            mkdir(outDir);
            unzip(archivePath, outDir);
            testCase.verifyFalse(isfolder(fullfile(outDir, ".git")), ...
                '.git directory should be excluded from archive');
        end

        function testBuildArchiveExcludesGlob(testCase)
            pkg = testCase.validPkgJson();
            projectDir = testCase.createMockProject(pkg);
            cd(projectDir);
            archivePath = fullfile(testCase.TempDir, "test_glob.zip");
            evalc('tbxmanager("internal__", "buildArchive", archivePath, ".git", "*.mat")');

            outDir = fullfile(testCase.TempDir, "unzipped_glob");
            mkdir(outDir);
            unzip(archivePath, outDir);
            matFiles = dir(fullfile(outDir, '**', '*.mat'));
            testCase.verifyEmpty(matFiles, '.mat files should be excluded from archive');
        end

        function testBuildArchiveEmpty(testCase)
            % Create a project with only files that will be excluded
            projectDir = fullfile(testCase.TempDir, "only_excluded");
            mkdir(projectDir);
            fid = fopen(fullfile(projectDir, "data.mat"), 'w');
            fwrite(fid, uint8(zeros(1, 16)));
            fclose(fid);
            cd(projectDir);
            archivePath = fullfile(testCase.TempDir, "test_empty.zip");
            testCase.verifyError( ...
                @() tbxmanager("internal__", "buildArchive", archivePath, "*.mat"), ...
                'TBXMANAGER:EmptyArchive');
        end

    end
end
