function t_008
% tests double installing

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% set up the test repo
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml

tbxmanager install tbx1
tbxmanager install tbx1

end
