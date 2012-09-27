function t_001
% "tbxmanager" should:
% * print the help
% * set the path to pwd

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

tbxmanager

end
