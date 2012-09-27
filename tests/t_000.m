function t_000
% tests error messages

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

try, tbxmanager install, end
try, tbxmanager uninstall, end
try, tbxmanager enable, end
try, tbxmanager disable, end
try, tbxmanager source, end
try, tbxmanager source add, end
try, tbxmanager source remove, end

end
