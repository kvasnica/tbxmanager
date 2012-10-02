function t_003
% tbxmanager sources add/remove

onCleanup(@(x) tbx_setupTest('done')); tbx_setupTest('start');

% full syntax, default source
tbxmanager show sources

% full syntax, custom source
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager show sources

% adding the same source twice
tbxmanager source add http://control.ee.ethz.ch/~mpt/tbx/test/test.xml

% short syntax, remove all sources, the default should stay
tbxmanager so re http://www.tbxmanager.com/package/index.xml
tbxmanager show sources
tbxmanager sour re http://control.ee.ethz.ch/~mpt/tbx/test/test.xml
tbxmanager show sources

% short syntax, custom source
tbxmanager so a http://control.ee.ethz.ch/~mpt/tbx/test/test.xml

% short syntax
tbxmanager sh so

end
