classdef TestVersionConstraints < matlab.unittest.TestCase
    % Tests for version parsing, comparison, and constraint satisfaction.

    methods (Test)

        % --- parseVersion ---

        function testParseThreePartVersion(testCase)
            result = tbxmanager("internal__", "parseVersion", "1.2.3");
            testCase.verifyEqual(result, [1 2 3]);
        end

        function testParseTwoPartVersion(testCase)
            result = tbxmanager("internal__", "parseVersion", "3.1");
            testCase.verifyEqual(result, [3 1 0]);
        end

        function testParseOnePartVersion(testCase)
            result = tbxmanager("internal__", "parseVersion", "5");
            testCase.verifyEqual(result, [5 0 0]);
        end

        function testParseZeroVersion(testCase)
            result = tbxmanager("internal__", "parseVersion", "0.0.0");
            testCase.verifyEqual(result, [0 0 0]);
        end

        % --- compareVersions ---

        function testCompareEqual(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.2.3", "1.2.3");
            testCase.verifyEqual(result, 0);
        end

        function testCompareLess(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.0.0", "2.0.0");
            testCase.verifyEqual(result, -1);
        end

        function testCompareGreater(testCase)
            result = tbxmanager("internal__", "compareVersions", "3.0.0", "2.9.9");
            testCase.verifyEqual(result, 1);
        end

        function testCompareMinorDiff(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.1.0", "1.2.0");
            testCase.verifyEqual(result, -1);
        end

        function testComparePatchDiff(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.2.4", "1.2.3");
            testCase.verifyEqual(result, 1);
        end

        function testCompareTwoVsThreePart(testCase)
            result = tbxmanager("internal__", "compareVersions", "1.2", "1.2.0");
            testCase.verifyEqual(result, 0);
        end

        % --- satisfiesConstraint ---

        function testSatisfiesGte(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", ">=1.0");
            testCase.verifyTrue(result);
        end

        function testFailsGte(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "0.9.0", ">=1.0");
            testCase.verifyFalse(result);
        end

        function testSatisfiesLt(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.9.0", "<2.0");
            testCase.verifyTrue(result);
        end

        function testFailsLt(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", "<2.0");
            testCase.verifyFalse(result);
        end

        function testSatisfiesExact(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.2.3", "==1.2.3");
            testCase.verifyTrue(result);
        end

        function testFailsExact(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.2.4", "==1.2.3");
            testCase.verifyFalse(result);
        end

        function testSatisfiesRange(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.5.0", ">=1.0,<2.0");
            testCase.verifyTrue(result);
        end

        function testFailsRangeUpper(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", ">=1.0,<2.0");
            testCase.verifyFalse(result);
        end

        function testSatisfiesCompatible(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.5.0", "~=1.2");
            testCase.verifyTrue(result);
        end

        function testFailsCompatible(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", "~=1.2");
            testCase.verifyFalse(result);
        end

        function testSatisfiesWildcard(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "99.0.0", "*");
            testCase.verifyTrue(result);
        end

        function testSatisfiesEmpty(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.0.0", "");
            testCase.verifyTrue(result);
        end

        % --- matlabReleaseNum ---

        function testReleaseNumA(testCase)
            result = tbxmanager("internal__", "matlabReleaseNum", "R2022a");
            testCase.verifyEqual(result, 2022.0);
        end

        function testReleaseNumB(testCase)
            result = tbxmanager("internal__", "matlabReleaseNum", "R2022b");
            testCase.verifyEqual(result, 2022.5);
        end

        function testReleaseNumLater(testCase)
            result = tbxmanager("internal__", "matlabReleaseNum", "R2024a");
            testCase.verifyEqual(result, 2024.0);
        end

    end
end
