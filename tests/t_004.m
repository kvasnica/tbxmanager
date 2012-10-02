function t_004
% tbxmanager install

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% set up the test repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager so re http://www.tbxmanager.com/package/index.xml
tbxmanager show sources

% nothing should be installed by default
tbxmanager show installed

tbxmanager show available

tbxmanager install tbx1 tbx2 tbx3
% tbx3 should be at version 2.0
tbxmanager in tbx3 
tbxmanager show installed

ls tbxstorage_test/
ls tbxstorage_test/tbx1
ls tbxstorage_test/tbx1/1.0
ls tbxstorage_test/tbx1/1.0/all
ls tbxstorage_test/tbx1/1.0/all/tbx1

ls tbxstorage_test/
ls tbxstorage_test/tbx2
ls tbxstorage_test/tbx2/1.0
ls tbxstorage_test/tbx2/1.0/all
ls tbxstorage_test/tbx2/1.0/all/tbx2

ls tbxstorage_test/
ls tbxstorage_test/tbx3
ls tbxstorage_test/tbx3/2.0
ls tbxstorage_test/tbx3/2.0/all
ls tbxstorage_test/tbx3/2.0/all/tbx3

end
