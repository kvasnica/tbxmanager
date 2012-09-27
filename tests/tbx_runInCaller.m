function [worked, msg] = tbx_runInCaller(statement)
% evaluates 'statement' in the caller's workspace and returns boolean flag
% 'worked' (true if no errors, false otherwise) and the error message in
% 'msg' (if any)

try
	msg = evalc('evalin(''caller'', statement)');
	worked = true;
catch
	worked = false;
	LE = lasterror;
	msg = LE.message;
end
