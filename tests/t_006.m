function t_006
% tbxmanager update

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% set up the test repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager so re http://control.ee.ethz.ch/~mpt/tbx/ifa.xml
tbxmanager show sources

% install two packages
tbxmanager install tbx1 tbx2 tbx3 tbx4
tbxmanager show installed

% add a new repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test_update.xml

% update just tbx2
tbxmanager up tbx2

% update all should update tbx1, tbx3
tbxmanager up

end
