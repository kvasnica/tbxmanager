function t_002
% "tbxmanager show sources" should return just the default

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% full syntax
tbxmanager show sources

% short syntax
tbxmanager sh so

end
