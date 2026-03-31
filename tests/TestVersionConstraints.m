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

        function testReleaseNumInvalid(testCase)
            testCase.verifyError( ...
                @() tbxmanager("internal__", "matlabReleaseNum", "notarelease"), ...
                'TBXMANAGER:InvalidRelease');
        end

        % --- parseConstraint additional operators ---

        function testParseConstraintLte(testCase)
            result = tbxmanager("internal__", "parseConstraint", "<=2.0");
            testCase.verifyEqual(string(result.op), "<=");
        end

        function testParseConstraintNeq(testCase)
            result = tbxmanager("internal__", "parseConstraint", "!=1.0");
            testCase.verifyEqual(string(result.op), "!=");
        end

        function testParseConstraintGtOnly(testCase)
            result = tbxmanager("internal__", "parseConstraint", ">1.0");
            testCase.verifyEqual(string(result.op), ">");
        end

        function testParseConstraintBareVersion(testCase)
            result = tbxmanager("internal__", "parseConstraint", "1.2.3");
            testCase.verifyEqual(string(result.op), "==");
            testCase.verifyEqual(string(result.version), "1.2.3");
        end

        function testParseConstraintCommaWildcard(testCase)
            % Comma-separated constraint where one part is "*"
            result = tbxmanager("internal__", "parseConstraint", ">=1.0,*");
            testCase.verifyEqual(numel(result), 2);
        end

        % --- satisfiesConstraint additional operators ---

        function testSatisfiesLte(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.0.0", "<=2.0");
            testCase.verifyTrue(logical(result));
        end

        function testFailsLte(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "3.0.0", "<=2.0");
            testCase.verifyFalse(logical(result));
        end

        function testSatisfiesGtOnly(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", ">1.0");
            testCase.verifyTrue(logical(result));
        end

        function testFailsGtOnly(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.0.0", ">1.0");
            testCase.verifyFalse(logical(result));
        end

        function testSatisfiesNeq(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "2.0.0", "!=1.0");
            testCase.verifyTrue(logical(result));
        end

        function testFailsNeq(testCase)
            result = tbxmanager("internal__", "satisfiesConstraint", "1.0.0", "!=1.0");
            testCase.verifyFalse(logical(result));
        end

        % --- satisfiesMatlabConstraint ---

        function testMatlabConstraintEmpty(testCase)
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "");
            testCase.verifyTrue(logical(result));
        end

        function testMatlabConstraintWildcard(testCase)
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "*");
            testCase.verifyTrue(logical(result));
        end

        function testMatlabConstraintLtePass(testCase)
            % Any MATLAB satisfies <=R9999a
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "<=R9999a");
            testCase.verifyTrue(logical(result));
        end

        function testMatlabConstraintEqFail(testCase)
            % R1990a is long before any real MATLAB
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "==R1990a");
            testCase.verifyFalse(logical(result));
        end

        function testMatlabConstraintLtPass(testCase)
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "<R9999a");
            testCase.verifyTrue(logical(result));
        end

        function testMatlabConstraintGtPass(testCase)
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", ">R2000a");
            testCase.verifyTrue(logical(result));
        end

        function testMatlabConstraintBareReleaseFail(testCase)
            result = tbxmanager("internal__", "satisfiesMatlabConstraint", "R1990a");
            testCase.verifyFalse(logical(result));
        end

        % --- parseVersion non-numeric parts ---

        function testParseVersionNonNumeric(testCase)
            % Non-numeric parts are treated as 0
            result = tbxmanager("internal__", "parseVersion", "1.x.0");
            testCase.verifyEqual(result, [1 0 0]);
        end

        function testMatlabRelease(testCase)
            % Covers the "matlabRelease" case in internal__ dispatch (L2684)
            result = tbxmanager("internal__", "matlabRelease");
            testCase.verifyTrue(ischar(result) || isstring(result), ...
                'matlabRelease should return a string');
            testCase.verifyTrue(strlength(string(result)) > 0, ...
                'matlabRelease should return non-empty release string');
        end

    end
end
