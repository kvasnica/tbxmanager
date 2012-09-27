function tbx_setupTest(mode)

global TBXMANAGER_TESTMODE

tbxdir = 'tbxstorage_test';

% double-check that we are indeed in the test directory
p = pwd;
if ~isequal(p(end-4:end), 'tests')
	error('Not in the test directory.');
end

switch mode,
	case 'start'
		% enabled the testing mode
		TBXMANAGER_TESTMODE.maindir = fileparts(which(mfilename));
		TBXMANAGER_TESTMODE.tbxdir = [TBXMANAGER_TESTMODE.maindir filesep tbxdir];
		TBXMANAGER_TESTMODE.server_url = '';
		
	case 'done'
		% disable the testing mode
		TBXMANAGER_TESTMODE = [];

	otherwise
		error('Unknown mode "%s". Allowed are "start" and "done".');
end

% remove any path pointing to tbxdir
w = warning; warning('off');
p = path;
while ~isempty(p)
	[t, p] = strtok(p, ':');
	if ~isempty(strfind(t, tbxdir))
		rmpath(t);
	end
end
try
	delete('tbxsources.txt');
	delete('tbxenabled.txt');
	system(['rm -rf ' tbxdir '/']);
end
rehash
warning(w);

end
