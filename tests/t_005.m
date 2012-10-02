function t_005
% tbxmanager enable/disable/restorepath

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% set up the test repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager so re http://www.tbxmanager.com/package/index.xml
tbxmanager show sources

% nothing should be installed by default
tbxmanager show installed

% nothing should be enabled by default
tbxmanager show enabled
tbxmanager sh en

% install some packages
tbxmanager install tbx1 tbx2 tbx3

% they should be enabled
tbxmanager show enabled
% double-check by displaying tbxenabled.txt
type tbxenabled.txt
% double-check the path
assert(~isempty(strfind(which('tbx1_v1.m'), 'tbxstorage_test')));
assert(~isempty(strfind(which('tbx2_v1.m'), 'tbxstorage_test')));
assert(~isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

% disable one
tbxmanager disable tbx3
tbxmanager show enab
% double-check
type tbxenabled.txt
assert(isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

% disable for the second time
tbxmanager dis tbx3
tbxmanager sh en

% enable back
tbxmanager en tbx3
tbxmanager sh en
type tbxenabled.txt
assert(~isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

% enable the same
tbxmanager en tbx3
assert(~isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

% disable all
tbxmanager dis tbx2 tbx3
tbxmanager sh en
assert(~isempty(strfind(which('tbx1_v1.m'), 'tbxstorage_test')));
assert(isempty(strfind(which('tbx2_v1.m'), 'tbxstorage_test')));
assert(isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));
type tbxenabled.txt

% enable all
tbxmanager enable tbx1 tbx2 tbx3

% manually remove from the path
w=warning; warning('off');
rmpath(genpath([fileparts(which(mfilename)) '/tbxstorage_test/']));
warning(w);
assert(isempty(strfind(which('tbx1_v1.m'), 'tbxstorage_test')));
assert(isempty(strfind(which('tbx2_v1.m'), 'tbxstorage_test')));
assert(isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

% restore path
tbxmanager restorepath
% all should be back
assert(~isempty(strfind(which('tbx1_v1.m'), 'tbxstorage_test')));
assert(~isempty(strfind(which('tbx2_v1.m'), 'tbxstorage_test')));
assert(~isempty(strfind(which('tbx3.m'), 'tbxstorage_test')));

end
