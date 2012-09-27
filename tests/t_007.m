function t_007
% tbxmanager uninstall

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% set up the test repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager so re http://control.ee.ethz.ch/~mpt/tbx/ifa.xml
tbxmanager show sources

% install two packages
tbxmanager install tbx1 tbx2 tbx3 tbx4
tbxmanager show installed

% uninstall some
tbxmanager uninstall tbx3 tbx4
tbxmanager show installed

% add a new repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test_update.xml

% update all should update tbx1, tbx2, tbx3
tbxmanager update tbx1 tbx2
% uninstall tbx2
tbxmanager uninstall tbx2

end
