function tbx_runTests

d = dir;
for i = 1:length(d)
	if ~d(i).isdir
		% process file
		[p, f, e] = fileparts(d(i).name);
		if ~isequal(e, '.m') || ~isequal(f(1:2), 't_')
			% only process test m-files
			continue
		end
		fprintf('%s... ', f);
		% read expected output
		expected = fileread([f '.out']);
		% remove spaces
		expected(expected<=32) = '';
		% replace placeholders
		expected = strrep(expected, '@current_date@', datestr(now, 1));
		% run the test, capture its output
		try
			actual = evalc(f);
			% remove spaces
			actual(actual<=32) = '';
			if isequal(actual, expected)
				fprintf('ok\n');
			else
				fprintf('wrong\n');
			end
		catch
			fprintf('error\n');
		end
	end
end

end
