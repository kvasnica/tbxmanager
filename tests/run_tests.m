function run_tests(varargin)
%RUN_TESTS  Run tests with pytest-style output.
%   run_tests              — run all tests in tests/
%   run_tests('Class')     — run a single test class
%   run_tests('-v')        — verbose: show each test name
%   run_tests('Class','-v')— combine both

    args = string(varargin);
    verbose = any(args == "-v");
    args(args == "-v") = [];

    addpath(genpath('.'));

    % Discover tests
    if isempty(args)
        suite = matlab.unittest.TestSuite.fromFolder('tests');
    else
        suite = matlab.unittest.TestSuite.fromFile(fullfile('tests', args(1) + ".m"));
    end

    % Run silently — capture all console output
    runner = matlab.unittest.TestRunner.withNoPlugins();
    t0 = tic;
    results = runner.run(suite);
    elapsed = toc(t0);

    ESC = char(27);
    GREEN  = ESC + "[32m";
    RED    = ESC + "[31m";
    YELLOW = ESC + "[33m";
    BOLD   = ESC + "[1m";
    DIM    = ESC + "[2m";
    RESET  = ESC + "[0m";
    % Move cursor to column N: ESC[NG
    GOTO75 = ESC + "[75G";

    nTotal = numel(results);
    nPassed = 0;
    nFailed = 0;
    nSkipped = 0;
    failures = {};

    % Group results by class
    classes = {};
    classResults = {};
    for i = 1:nTotal
        name = string(results(i).Name);
        parts = split(name, "/");
        cls = char(parts(1));
        idx = find(strcmp(classes, cls), 1);
        if isempty(idx)
            classes{end+1} = cls; %#ok<AGROW>
            classResults{end+1} = results(i); %#ok<AGROW>
        else
            classResults{idx}(end+1) = results(i);
        end
    end

    fprintf("\n");
    cumulative = 0;

    for c = 1:numel(classes)
        cls = classes{c};
        cResults = classResults{c};

        if verbose
            for j = 1:numel(cResults)
                r = cResults(j);
                if r.Passed
                    nPassed = nPassed + 1;
                    fprintf(" %sPASSED%s %s\n", GREEN, RESET, r.Name);
                elseif r.Failed
                    nFailed = nFailed + 1;
                    failures{end+1} = r; %#ok<AGROW>
                    fprintf(" %sFAILED%s %s\n", RED, RESET, r.Name);
                else
                    nSkipped = nSkipped + 1;
                    fprintf(" %sSKIPPED%s %s\n", YELLOW, RESET, r.Name);
                end
            end
        else
            % Compact: tests/Class.m .....F..s.             [XX%]
            fprintf("tests/%s.m ", cls);
            for j = 1:numel(cResults)
                r = cResults(j);
                if r.Passed
                    nPassed = nPassed + 1;
                    fprintf("%s.%s", GREEN, RESET);
                elseif r.Failed
                    nFailed = nFailed + 1;
                    failures{end+1} = r; %#ok<AGROW>
                    fprintf("%sF%s", RED, RESET);
                else
                    nSkipped = nSkipped + 1;
                    fprintf("%ss%s", YELLOW, RESET);
                end
            end
            cumulative = cumulative + numel(cResults);
            pct = floor(cumulative / nTotal * 100);
            % Jump cursor to column 75, print progress
            fprintf("%s%s[%3d%%]%s\n", GOTO75, DIM, pct, RESET);
        end
    end

    % Print failure details
    if ~isempty(failures)
        fprintf("\n%s%s========================= FAILURES =========================%s\n", BOLD, RED, RESET);
        for i = 1:numel(failures)
            r = failures{i};
            fprintf("\n%s%s___ %s ___%s\n", BOLD, RED, r.Name, RESET);
            if ~isempty(r.Details) && isfield(r.Details, 'DiagnosticRecord')
                records = r.Details.DiagnosticRecord;
                for j = 1:numel(records)
                    evt = records(j).Event;
                    if evt == "VerificationFailed" || evt == "AssertionFailed" || evt == "ExceptionThrown"
                        report = string(records(j).Report);
                        fprintf("%s\n", report);
                    end
                end
            end
        end
    end

    % Summary line
    if nFailed > 0
        color = RED;
    else
        color = GREEN;
    end

    parts = {};
    if nFailed > 0,  parts{end+1} = sprintf("%s%d failed%s",  RED, nFailed, RESET); end
    if nPassed > 0,  parts{end+1} = sprintf("%s%d passed%s",  GREEN, nPassed, RESET); end
    if nSkipped > 0, parts{end+1} = sprintf("%s%d skipped%s", YELLOW, nSkipped, RESET); end

    fprintf("\n%s%s=========%s %s %s%sin %.2fs%s %s%s=========%s\n", ...
        BOLD, color, RESET, ...
        strjoin(string(parts), ", "), ...
        BOLD, DIM, elapsed, RESET, ...
        BOLD, color, RESET);

    if nFailed > 0
        error('TBXMANAGER:TestsFailed', '%d test(s) failed.', nFailed);
    end
end
