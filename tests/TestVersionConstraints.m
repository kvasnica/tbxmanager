classdef TestVersionConstraints < matlab.unittest.TestCase
    % Tests for version parsing, comparison, and constraint satisfaction.

    methods (Test)

        % --- parseVersion ---

        function testParseThreePartVersion(testCase)
            tbxmanager("internal__", "parseVersion", "1.2.3");
            testCase.verifyEqual(ans, [1 2 3]);
        end

        function testParseTwoPartVersion(testCase)
            tbxmanager("internal__", "parseVersion", "3.1");
            testCase.verifyEqual(ans, [3 1 0]);
        end

        function testParseOnePartVersion(testCase)
            tbxmanager("internal__", "parseVersion", "5");
            testCase.verifyEqual(ans, [5 0 0]);
        end

        function testParseZeroVersion(testCase)
            tbxmanager("internal__", "parseVersion", "0.0.0");
            testCase.verifyEqual(ans, [0 0 0]);
        end

        % --- compareVersions ---

        function testCompareEqual(testCase)
            tbxmanager("internal__", "compareVersions", "1.2.3", "1.2.3");
            testCase.verifyEqual(ans, 0);
        end

        function testCompareLess(testCase)
            tbxmanager("internal__", "compareVersions", "1.0.0", "2.0.0");
            testCase.verifyEqual(ans, -1);
        end

        function testCompareGreater(testCase)
            tbxmanager("internal__", "compareVersions", "3.0.0", "2.9.9");
            testCase.verifyEqual(ans, 1);
        end

        function testCompareMinorDiff(testCase)
            tbxmanager("internal__", "compareVersions", "1.1.0", "1.2.0");
            testCase.verifyEqual(ans, -1);
        end

        function testComparePatchDiff(testCase)
            tbxmanager("internal__", "compareVersions", "1.2.4", "1.2.3");
            testCase.verifyEqual(ans, 1);
        end

        function testCompareTwoVsThreePart(testCase)
            tbxmanager("internal__", "compareVersions", "1.2", "1.2.0");
            testCase.verifyEqual(ans, 0);
        end

        % --- satisfiesConstraint ---

        function testSatisfiesGte(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "2.0.0", ">=1.0");
            testCase.verifyTrue(ans);
        end

        function testFailsGte(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "0.9.0", ">=1.0");
            testCase.verifyFalse(ans);
        end

        function testSatisfiesLt(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.9.0", "<2.0");
            testCase.verifyTrue(ans);
        end

        function testFailsLt(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "2.0.0", "<2.0");
            testCase.verifyFalse(ans);
        end

        function testSatisfiesExact(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.2.3", "==1.2.3");
            testCase.verifyTrue(ans);
        end

        function testFailsExact(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.2.4", "==1.2.3");
            testCase.verifyFalse(ans);
        end

        function testSatisfiesRange(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.5.0", ">=1.0,<2.0");
            testCase.verifyTrue(ans);
        end

        function testFailsRangeUpper(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "2.0.0", ">=1.0,<2.0");
            testCase.verifyFalse(ans);
        end

        function testSatisfiesCompatible(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.5.0", "~=1.2");
            testCase.verifyTrue(ans);
        end

        function testFailsCompatible(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "2.0.0", "~=1.2");
            testCase.verifyFalse(ans);
        end

        function testSatisfiesWildcard(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "99.0.0", "*");
            testCase.verifyTrue(ans);
        end

        function testSatisfiesEmpty(testCase)
            tbxmanager("internal__", "satisfiesConstraint", "1.0.0", "");
            testCase.verifyTrue(ans);
        end

        % --- matlabReleaseNum ---

        function testReleaseNumA(testCase)
            tbxmanager("internal__", "matlabReleaseNum", "R2022a");
            testCase.verifyEqual(ans, 2022.0);
        end

        function testReleaseNumB(testCase)
            tbxmanager("internal__", "matlabReleaseNum", "R2022b");
            testCase.verifyEqual(ans, 2022.5);
        end

        function testReleaseNumLater(testCase)
            tbxmanager("internal__", "matlabReleaseNum", "R2024a");
            testCase.verifyEqual(ans, 2024.0);
        end

    end
end
