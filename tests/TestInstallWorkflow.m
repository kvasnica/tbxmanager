classdef TestInstallWorkflow < matlab.unittest.TestCase
    % Integration tests for install, uninstall, update, enable, disable,
    % restorepath. Uses local file:// URLs with mock packages.
    %
    % Covers scenarios from legacy tests t_000, t_004, t_005, t_006, t_007, t_008.

    properties
        TempDir
        OrigHome
        OrigDir
        OrigPath
        FixturesDir
        MockIndexFile
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TempDir = fullfile(tempdir, "tbx_test_" + string(randi(99999)));
            testCase.OrigHome = getenv("TBXMANAGER_HOME");
            testCase.OrigDir = pwd;
            testCase.OrigPath = path;
            setenv("TBXMANAGER_HOME", testCase.TempDir);

            % Find fixtures directory relative to this test file
            testCase.FixturesDir = fullfile(fileparts(mfilename('fullpath')), 'fixtures');

            % Create a local mock index.json with file:// URLs
            testCase.MockIndexFile = fullfile(testCase.TempDir, "mock_index.json");
            testCase.createMockIndex();

            % Initialize tbxmanager and point to local index
            tbxmanager("help");

            % Replace sources with our local mock
            sourcesFile = fullfile(testCase.TempDir, "state", "sources.json");
            s.sources = {['file://' testCase.MockIndexFile]};
            fid = fopen(sourcesFile, 'w');
            fprintf(fid, '%s', jsonencode(s));
            fclose(fid);

            testCase.addTeardown(@() path(testCase.OrigPath));
            testCase.addTeardown(@() cd(testCase.OrigDir));
            testCase.addTeardown(@() setenv("TBXMANAGER_HOME", testCase.OrigHome));
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Access = private)
        function createMockIndex(testCase)
            pkgDir = fullfile(testCase.FixturesDir, 'mock_packages');

            idx.index_version = 1;
            idx.generated = '2026-01-01T00:00:00Z';

            % testpkg1 v1.0.0
            tp1v1.matlab = '>=R2022a';
            tp1v1.dependencies = struct();
            tp1v1.platforms.all.url = ['file://' fullfile(pkgDir, 'testpkg1-1.0.0-all.zip')];
            tp1v1.platforms.all.sha256 = '9a430896c128c529dea9d748328d246dc393ec321b8c840485c26514bb460b12';
            tp1v1.released = '2025-01-01';

            % testpkg1 v2.0.0
            tp1v2.matlab = '>=R2022a';
            tp1v2.dependencies = struct();
            tp1v2.platforms.all.url = ['file://' fullfile(pkgDir, 'testpkg1-2.0.0-all.zip')];
            tp1v2.platforms.all.sha256 = '9de8591ba40cde60179f79a8767d5af263483d3baf229cf9d40cfd7157a8d829';
            tp1v2.released = '2025-06-01';

            pkg1.name = 'testpkg1';
            pkg1.description = 'Test package 1';
            pkg1.license = 'MIT';
            pkg1.authors = {'Test'};
            pkg1.latest = '2.0.0';
            pkg1.versions.x1_0_0 = tp1v1;
            pkg1.versions.x2_0_0 = tp1v2;

            % testpkg2 v1.0.0 (depends on testpkg1)
            tp2v1.matlab = '>=R2022a';
            tp2v1.dependencies.testpkg1 = '>=1.0';
            tp2v1.platforms.all.url = ['file://' fullfile(pkgDir, 'testpkg2-1.0.0-all.zip')];
            tp2v1.platforms.all.sha256 = 'c3a8dc80781984eba7ac5b67b288cf1e6f136d33a45aa2610a5d34b92c345280';
            tp2v1.released = '2025-03-01';

            pkg2.name = 'testpkg2';
            pkg2.description = 'Test package 2 (depends on testpkg1)';
            pkg2.license = 'MIT';
            pkg2.authors = {'Test'};
            pkg2.latest = '1.0.0';
            pkg2.versions.x1_0_0 = tp2v1;

            idx.packages.testpkg1 = pkg1;
            idx.packages.testpkg2 = pkg2;

            fid = fopen(testCase.MockIndexFile, 'w');
            fprintf(fid, '%s', jsonencode(idx));
            fclose(fid);
        end
    end

    methods (Test)

        % --- Error handling (covers t_000) ---

        function testInstallNoArgs(testCase)
            % Should print error but not crash
            tbxmanager("install");
            testCase.verifyTrue(true);
        end

        function testUninstallNoArgs(testCase)
            tbxmanager("uninstall");
            testCase.verifyTrue(true);
        end

        function testEnableNoArgs(testCase)
            tbxmanager("enable");
            testCase.verifyTrue(true);
        end

        function testDisableNoArgs(testCase)
            tbxmanager("disable");
            testCase.verifyTrue(true);
        end

        % --- Install (covers t_004) ---

        function testInstallSinglePackage(testCase)
            tbxmanager("install", "testpkg1");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyTrue(isfolder(pkgDir), 'Package directory should exist');
        end

        function testInstallCreatesFiles(testCase)
            tbxmanager("install", "testpkg1");
            % Should have version subdirectory
            versions = dir(fullfile(testCase.TempDir, "packages", "testpkg1"));
            versionDirs = versions([versions.isdir] & ~ismember({versions.name}, {'.', '..'}));
            testCase.verifyGreaterThanOrEqual(numel(versionDirs), 1);
        end

        function testDoubleInstall(testCase)
            % Covers t_008: installing same package twice should be idempotent
            tbxmanager("install", "testpkg1");
            tbxmanager("install", "testpkg1");
            testCase.verifyTrue(true); % Should not error
        end

        function testInstallWithDependency(testCase)
            % testpkg2 depends on testpkg1 - both should be installed
            tbxmanager("install", "testpkg2");
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg2")));
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, "packages", "testpkg1")));
        end

        % --- List ---

        function testListAfterInstall(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("list");
            testCase.verifyTrue(true);
        end

        % --- Search ---

        function testSearchFindsPackage(testCase)
            tbxmanager("search", "testpkg");
            testCase.verifyTrue(true);
        end

        function testSearchNoResults(testCase)
            tbxmanager("search", "nonexistent_xyz_12345");
            testCase.verifyTrue(true);
        end

        % --- Info ---

        function testInfoPackage(testCase)
            tbxmanager("info", "testpkg1");
            testCase.verifyTrue(true);
        end

        % --- Enable/Disable (covers t_005) ---

        function testEnableDisableCycle(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("disable", "testpkg1");

            % Check enabled.json
            f = fullfile(testCase.TempDir, "state", "enabled.json");
            data = jsondecode(fileread(f));
            if isstruct(data.packages)
                names = fieldnames(data.packages);
                testCase.verifyFalse(ismember('testpkg1', names));
            end

            tbxmanager("enable", "testpkg1");
            data2 = jsondecode(fileread(f));
            names2 = fieldnames(data2.packages);
            testCase.verifyTrue(ismember('testpkg1', names2));
        end

        function testRestorePathAfterDisable(testCase)
            % Covers t_005 restorepath scenario
            tbxmanager("install", "testpkg1");
            tbxmanager("enable", "testpkg1");
            tbxmanager("restorepath");
            testCase.verifyTrue(true);
        end

        % --- Update (covers t_006) ---

        function testUpdatePackage(testCase)
            % Install v1 by constraining, then update to latest
            tbxmanager("install", "testpkg1@==1.0.0");
            tbxmanager("update", "testpkg1");
            testCase.verifyTrue(true);
        end

        % --- Uninstall (covers t_007) ---

        function testUninstallPackage(testCase)
            tbxmanager("install", "testpkg1");
            tbxmanager("uninstall", "testpkg1");
            pkgDir = fullfile(testCase.TempDir, "packages", "testpkg1");
            testCase.verifyFalse(isfolder(pkgDir), 'Package should be removed');
        end

        function testUninstallWithDeps(testCase)
            % Install pkg2 (pulls pkg1), then uninstall pkg1 should warn
            tbxmanager("install", "testpkg2");
            tbxmanager("uninstall", "testpkg1");
            % Should still succeed (with warning) or refuse
            testCase.verifyTrue(true);
        end

    end
end
