function tbxmanager(command, varargin)
% Toolbox manager
%
% Supported commands:
%   tbxmanager install package1 package2 ...
%   tbxmanager show enabled
%   tbxmanager show installed
%   tbxmanager show available
%   tbxmanager show sources
%   tbxmanager update
%   tbxmanager update package1 package2 ...
%   tbxmanager restorepath
%   tbxmanager enable package1 package2 ...
%   tbxmanager disable package1 package2 ...
%   tbxmanager uninstall package1 package2 ...
%   tbxmanager source add URL
%   tbxmanager source remove URL
%   tbxmanager selfupdate
%
% For help, contact michal.kvasnica@stuba.sk

% Copyright is with the following author(s):
%
% (c) 2012 Michal Kvasnica, Slovak University of Technology in Bratislava
%          michal.kvasnica@stuba.sk

% ------------------------------------------------------------------------
% Legal note:
%   This program is free software; you can redistribute it and/or
%   modify it under the terms of the GNU General Public
%   License as published by the Free Software Foundation; either
%   version 2.1 of the License, or (at your option) any later version.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%   General Public License for more details.
%
%   You should have received a copy of the GNU General Public
%   License along with this library; if not, write to the
%     Free Software Foundation, Inc.,
%     59 Temple Place, Suite 330,
%     Boston, MA  02111-1307  USA
% ------------------------------------------------------------------------

%% check if java is running
if ~usejava('jvm')
    error('TBXMANAGER:NOJAVA', 'Java virtual machine must be running.');
end

%% add self to path
addpath(fileparts(which(mfilename)));

if nargin==0
	help(mfilename);
	return
end

%% validate input arguments
if ~ischar(command)
	error('TBXMANAGER:BADCOMMAND', 'The command must be a string.');
end
for i = 1:length(varargin)
	if ~ischar(varargin{i})
		error('TBXMANAGER:BADCOMMAND', 'All arguments must be strings.');
	end
end

%% expand commands
supported_commands = {'install', ...
	'update', ...
	'restorepath', ...
	'enable', ...
	'disable', ...
	'uninstall', ...
	'show', ...
	'source', ...
	'selfupdate'};
% expand command name, e.g. "sh" -> "show"
command = tbx_expandChoice(lower(command), supported_commands);

%% dispatch commands
args = varargin;
switch lower(command)
	case 'install',
		cmd = @main_install;
	case 'update',
		if isempty(args)
			cmd = @main_updateall;
		else
			cmd = @main_update;
		end
	case 'restorepath',
		cmd = @tbx_restorePath;
	case 'enable',
		cmd = @main_addpath;
	case 'disable',
		cmd = @main_rmpath;
	case 'uninstall',
		cmd = @main_uninstall;
	case 'show',
		cmd = @main_show;
	case 'source'
		cmd = @main_source;
	case 'selfupdate'
		cmd = @main_selfupdate;
	otherwise
		help(mfilename);
		error('TBXMANAGER:BADCOMMAND', 'Unrecognized command "%s".', command);
end

% safely execute the command
try
	feval(cmd, args);
catch
	err = lasterror;
	if ~isempty(err.identifier) && isempty(strfind(err.identifier, 'TBXMANAGER'))
		% unexpected error
		fprintf('\n----------------------------------------------------\n');
		fprintf('Oooops, an error has occurred.\n');
		fprintf('\n');
		fprintf('Run "tbxmanager selfupdate" and repeat your action.\n');
		fprintf('\n');
		fprintf('If problems remain, contact michal.kvasnica@stuba.sk\n');
		fprintf('----------------------------------------------------\n\n');
		rethrow(lasterror);
	else
		% expected error
		fprintf('\n%s\n\n', err.message);
		error('TBXMANAGER:ERROR', 'Cannot continue, see message above.');
	end
end

end

%%
function C = tbx_crc32(data)
% returns CRC32 checksum of given data

crc_gen = java.util.zip.CRC32;
crc_gen.update(double(data));
C = crc_gen.getValue();

end

%%
function main_selfupdate(args)
% updates this file

Setup = tbx_setup;
% get a simple CRC of the current version
this_file = [Setup.maindir filesep mfilename '.m'];
this_content = fileread(this_file);

other_content = urlread(Setup.selfurl);
other_crc = sum(other_content);
if tbx_crc32(this_content) == tbx_crc32(other_content)
	fprintf('You already have the newest version of tbxmanager.\n');
else
	% make a copy of the current version just to be sure
	if ~copyfile(this_file, [this_file '.old']);
		error('TBXMANAGER:FILEERROR', 'Couldn''t back up %s to %s.', this_file, ...
			[this_file '.old']);
	end
	urlwrite(Setup.selfurl, this_file);
	rehash
	fprintf('tbxmanager updated to latest version.\n');
end

end

%%
function main_source(args)
% manages sources
%
%   source add URL
%   source remove URL

if length(args)~=2
	error('TBXMANAGER:BADCOMMAND', ...
		'The "source" command requires two additional inputs.');
end

% expand the argument, e.g. "a" -> "add", "rem" -> "remove"
arg_choices = { 'add', 'remove' };
main_arg = tbx_expandChoice(lower(args{1}), arg_choices);

Setup = tbx_setup;
switch main_arg
	case 'add',
		if length(args)<2
			error('TBXMANAGER:BADCOMMAND', '"source add" requires an URL.');
		end
		tbx_addSource(Setup.sourcesfile, args{2});
		
	case 'remove'
		if length(args)<2
			error('TBXMANAGER:BADCOMMAND', '"source remove" requires an URL.');
		end
		tbx_removeSource(Setup.sourcesfile, args{2});
		
	otherwise
		error('TBXMANAGER:BADCOMMAND', ...
			'Unrecognized option "%s". Allowed are "add" and "remove".', main_arg);
end

end

%%
function setup = tbx_setup(maindir)
% Sets up parameters of TBXMANAGER

if nargin==0
	maindir = fileparts(which(mfilename));
end

% where toolboxes are stored
setup.tbxdir = [maindir filesep 'toolboxes'];
if ~exist(setup.tbxdir, 'dir')
	mkdir(setup.tbxdir);
end

% where the main tbxmanager directory is
setup.maindir = maindir;

setup.sourcesfile = [maindir filesep 'tbxsources.txt'];
try
	setup.sources = tbx_getSources(setup.sourcesfile);
catch
	setup.sources = [];
end
if isempty(setup.sources)
	% default cell list of sources
	setup.sources = { 'http://control.ee.ethz.ch/~mpt/tbx/ifa.xml' };
	tbx_writeSources(setup.sourcesfile, setup.sources);
end

% file where list of enabled toolboxes is stored
setup.enabledfile = [maindir filesep 'tbxenabled.txt'];

% where on the web is tbxmanager?
setup.selfurl = 'http://control.ee.ethz.ch/~mpt/tbx/tbxmanager.m';

end

%%
function sources = tbx_getSources(fname)
% returns list of sources loaded from tbxmanager_sources.txt

if exist(fname, 'file')
	s = textscan(fileread(fname), '%s');
	sources = s{1};
else
	sources = {};
end

end

%%
function tbx_writeSources(fname, sources)
% writes list of soruces to tbxmanager_sources.txt

fid = fopen(fname, 'w');
if fid < 0
	error('TBXMANAGER:FILEERROR', 'Couldn''t open %s for writing.', fname);
end
for i = 1:length(sources)
	fprintf(fid, '%s\n', sources{i});
end
fclose(fid);

end

%%
function tbx_addSource(fname, source)
% adds the source to tbxmanager_sources.txt

% is the source valid?
try
	urlread(source);
catch
	error('TBXMANAGER:URLERROR', 'Unable to connect to %s', source);
end
% load the sources
sources = tbx_getSources(fname);
% is the source there?
if ~isempty(strmatch(source, sources))
	fprintf('Source "%s" is already on the list.\n', source);
else
	% add it
	sources{end+1} = source;
	% and write back
	tbx_writeSources(fname, sources);
end

end

%%
function tbx_removeSource(fname, source)
% removes the source from tbxmanager_sources.txt

% load the sources
sources = tbx_getSources(fname);
nbefore = length(sources);
% remove the source
sources = setdiff(sources, source);
if length(sources)==nbefore
	% no source was removed
	fprintf('Source "%s" is not on the list.\n', source);
else
	% and write back
	tbx_writeSources(fname, sources);
end

end

%%
function main_show(args)
% shows available/installed/enabled packages or sources

if isempty(args)
	main_show({'available'});
	fprintf('\n');
	main_show({'installed'});
	return
end

% expand the argument, e.g. "a" -> "available", "inst" -> "installed"
arg_choices = { 'available', 'installed', 'enabled', 'sources' };
main_arg = tbx_expandChoice(lower(args{1}), arg_choices);

switch lower(main_arg)
	case 'sources'
		Setup = tbx_setup;
		fprintf('Active sources:\n\n');
		sources = Setup.sources;
		for i = 1:length(sources)
			fprintf('%s\n', sources{i});
		end
		return
	case 'installed',
		L = tbx_listInstalled();
		fprintf('Locally installed packages:\n\n');
	case 'available',
		L = tbx_listAvailable();
		fprintf('Packages available for download:\n\n');
	case 'enabled',
		L = tbx_loadEnabled();
		fprintf('List of enabled packages:\n\n');
		names = unique(arrayfun(@(x) x.name, L, 'UniformOutput', false));
		maxname = max(cellfun('length', names));
		for i = 1:length(L)
			fprintf('%s %s Version %s\n', L(i).name, ...
				repmat(' ', 1, max(1, 1+maxname-length(L(i).name))), ...
				L(i).version);
		end
		return
	otherwise,
		error('TBXMANAGER:BADCOMMAND', ...
			'Unknown mode ''%s''. Allowed are ''installed'', ''available'', ''enabled'', ''sources''.', main_arg);
end

% get just names of toolboxes
names = unique(arrayfun(@(x) x.name, L, 'UniformOutput', false));
maxname = max(cellfun('length', names));
for i = 1:length(names)
	Latest = tbx_getLatestVersion(L, names{i});
	fprintf('%s %s Version %s', Latest.name, ...
		repmat(' ', 1, max(1, 1+maxname-length(Latest.name))), ...
		Latest.version);
	if isfield(Latest, 'date')
		fprintf('%s(%s)', repmat(' ', 1, max(1, 10-length(Latest.version))), ...
			datestr(datenum(Latest.date), 1));
	end
	fprintf('\n');
end

end

%%
function main_install(names)
% installs multiple toolboxes

validate_notempty(names);
validate_available(names);

Available = tbx_listAvailable();
for i = 1:length(names)
	Latest = tbx_getLatestVersion(Available, names{i});
	if tbx_isInstalled(Latest)
		fprintf('Latest version of "%s" is already installed.\n', names{i});
	else
		fprintf('\n');
		fprintf('Installing version "%s" of "%s"...\n', Latest.version, ...
			Latest.name);
		tbx_install(Latest);
		tbx_addPath(Latest);
	end
end

end

%%
function main_addpath(names)
% adds selected toolboxes to the Matlab path

validate_notempty(names);
validate_installed(names);

Installed = tbx_listInstalled();
for i = 1:length(names)
	[~, w] = tbx_isOnList(Installed, names{i});
	if length(w)>1
		% more than one version installed, add the latest
		Latest = tbx_getLatestVersion(Instealled, names{i});
	else
		Latest = Installed(w);
	end
	tbx_addPath(Latest);
end

end

%%
function main_rmpath(names)
% removes selected toolboxes to the Matlab path

validate_notempty(names);
validate_installed(names);

Installed = tbx_listInstalled();
for i = 1:length(names)
	[~, w] = tbx_isOnList(Installed, names{i});
	if length(w)>1
		% more than one version installed, add the latest
		Latest = tbx_getLatestVersion(Installed, names{i});
	else
		Latest = Installed(w);
	end
	tbx_rmPath(Latest);
end

end


%%
function main_updateall(args)
% updates all locally installed toolboxes

Installed = tbx_listInstalled();
% get just names of the toolboxes
names = unique(arrayfun(@(x) x.name, Installed, 'UniformOutput', false));

main_update(names);

end

%%
function main_update(names)
% updates selected locally installed toolboxes

validate_notempty(names);
validate_installed(names);

Available = tbx_listAvailable();
for i = 1:length(names)
	Latest = tbx_getLatestVersion(Available, names{i});
	if tbx_isInstalled(Latest)
		fprintf('No new version for toolbox "%s".\n', names{i});
	else
		% install newer version
		fprintf('Toolbox "%s" has new version "%s", installing...\n', ...
			Latest.name, Latest.version);
		tbx_install(Latest);
		tbx_addPath(Latest);
	end
end

end

%%
function main_uninstall(names)
% installs multiple toolboxes

validate_notempty(names);
validate_installed(names);

Installed = tbx_listInstalled();
for i = 1:length(names)
	% get all installed versions
	[~, w] = tbx_isOnList(Installed, names{i});
	for j = 1:length(w)
		fprintf('\n');
		Toolbox = Installed(w(j));
		tbx_rmPath(Toolbox);
		tbx_uninstall(Toolbox);
	end
end

end

%%
function validate_notempty(names)

if isempty(names)
	error('TBXMANAGER:BADCOMMAND', 'Name of a toolbox must be provided.');
end

end

%%
function validate_available(names)
% shows an error if some toolbox is not available online

Available = tbx_listAvailable();
for i = 1:length(names)
	if ~tbx_isOnList(Available, names{i})
		error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not available.', names{i});
	end
end

end

%%
function validate_installed(names)
% shows an error if some toolbox is not installed locally

Installed = tbx_listInstalled();
for i = 1:length(names)
	if ~tbx_isOnList(Installed, names{i})
		error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not installed.', names{i});
	end
end

end

%%
function tbx_addPath(Toolbox)
% Adds the given toolbox from MATLAB path
%
% Specification of the input structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

if ~tbx_isInstalled(Toolbox)
	error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not installed.', tbx_s2n(Toolbox));
end

% remove any previous instances of this toolbox from the path
[archdir, ~, basedir] = tbx_installationDir(Toolbox);
w = warning; warning('off');
rmpath(genpath(basedir));
warning(w);

% set path to this particular toolbox
addpath(genpath([archdir filesep]));
rehash pathreset

fprintf('Toolbox "%s" added to the Matlab path.\n', tbx_s2n(Toolbox));

tbx_registerEnabled(Toolbox);

end

%%
function Latest = tbx_getLatestVersion(List, name)
% Returns specifications of a new version for a particular architecture

if ~tbx_isOnList(List, name)
	error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not available.', name);
end

% get list of versions for this toolbox and architecture
candidates = false(1, length(List));
for i = 1:length(List)
	if isequal(List(i).name, name) && ...
			tbx_isArchCompatible(List(i).arch)
		candidates(i) = true;
	end
end
List = List(candidates);

% get the latest version
dates = zeros(1, length(List));
for i = 1:length(List)
	dates(i) = datenum(List(i).date);
end
[~, b] = sort(dates);
Latest = List(b(end)); % newest is the last in the list

end

%%
function tbx_install(Toolbox)
% Downloads and installs single toolbox
%
% Specification of the input structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture
%      url: download url

if tbx_isInstalled(Toolbox)
	error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is already installed.', tbx_s2n(Toolbox));
end

% Extract name of the installation package from the URL
seps = find(Toolbox.url=='/');
if isempty(seps)
	error('TBXMANAGER:BADCOMMAND', 'Malformed URL.');
end
install_file = Toolbox.url(seps(end)+1:end);
if isempty(install_file)
	error('TBXMANAGER:URLERROR', 'No file found in the URL.');
end
% Detect extension
[p, n, extension] = fileparts(install_file);
if isempty(extension)
	error('TBXMANAGER:URLERROR', 'No file found in the URL.');
end
switch lower(extension(2:end))
	case 'zip',
		isarchive = true;
		unpacker = @unzip;
	case {'tgz', 'tar'},
		isarchive = true;
		unpacker = @untar;
	case 'm',
		isarchive = false;
	otherwise,
		error('TBXMANAGER:URLERROR', 'Unsupported file extension "%s".', extension);
end

% Create installation directory
install_dir = tbx_installationDir(Toolbox);
if ~exist(install_dir, 'dir') && ~mkdir(install_dir)
	error('TBXMANAGER:FILEERROR', 'Couldn''t create directory "%s".', install_dir);
end

% Download the package to install_dir
download_to = [install_dir filesep install_file];
fprintf('Downloading "%s"...\n', Toolbox.url);
try
	urlwrite(Toolbox.url, download_to);
catch
	% remove the created directory
	rmdir(install_dir, 's');
	rethrow(lasterror);
end
if ~exist(download_to, 'file')
	error('TBXMANAGER:URLERROR', 'Download failed.');
end

% Unpack
if isarchive
	unpacker(download_to, install_dir);
end
fprintf('"%s" installed to %s\n', tbx_s2n(Toolbox), install_dir);

% Delete the downloaded package
if isarchive
	delete(download_to);
end

% TODO: Find and run installation scripts

end

%%
function [archdir, versiondir, basedir] = tbx_installationDir(Toolbox)
% Returns directory which contains installation of a given toolbox
%
% Specification of the input structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

Setup = tbx_setup;
basedir = [Setup.tbxdir filesep Toolbox.name];
versiondir = [basedir filesep Toolbox.version];
archdir = [versiondir filesep Toolbox.arch];

end

%%
function status = tbx_isArchCompatible(arch)
% Returns true if the architecture is compatible with the current system

status = isequal(lower(arch), 'all') || isequal(upper(arch), computer);

end

%%
function flag = tbx_isInstalled(Toolbox)
% Returns true if a given toolbox is installed
%
% Toolbox is described by a structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

List = tbx_listInstalled;
for i = 1:length(List)
	if isempty(Toolbox.version)
		List(i).version = '';
	end
	if isempty(Toolbox.arch)
		List(i).arch = '';
	end
	if isequal(List(i).name, Toolbox.name) && ...
			isequal(List(i).version, Toolbox.version) && ...
			isequal(List(i).arch, Toolbox.arch)
		flag = true;
		return
	end
end
flag = false;

end

%%
function [status, where] = tbx_isOnList(List, Toolbox)
% Returns true if a particural toolbox is available online

Toolbox = tbx_n2s(Toolbox);

where = false(1, length(List));
for i = 1:length(List)
	if isequal(Toolbox.name, List(i).name)
		if isequal(Toolbox.version, List(i).version) && ...
				isequal(Toolbox.arch, List(i).arch)
			status = true;
			where(i) = true;
		elseif isempty(Toolbox.version) && isempty(Toolbox.arch)
			status = true;
			where(i) = true;
		elseif isempty(Toolbox.version) && isequal(Toolbox.arch, List(i).arch)
			status = true;
			where(i) = true;
		elseif isempty(Toolbox.arch) && isequal(Toolbox.version, List(i).version)
			status = true;
			where(i) = true;
		end
	end
end
status = any(where);
where = find(where);

end

%%
function L = tbx_listAvailable
% Loads list of toolboxes from a given source (URL or file)

% TODO: support multiple sources
Setup = tbx_setup;
if ~iscell(Setup.sources)
	Setup.source = { Setup.sources };
end

L = tbx_loadSource(Setup.sources{1});
for i = 2:length(Setup.sources)
	L = [L tbx_loadSource(Setup.sources{i})];
end
L;

end

%%
function L = tbx_loadSource(source)
% Internal helper to load list of available toolboxes from a since source

if ~exist(source, 'file')
	% make a local copy of the network file
	xml = urlread(source);
	source = tempname;
	fid = fopen(source, 'w');
	fprintf(fid, '%s\n', xml);
	fclose(fid);
	X = xml2struct(source);
	delete(source);
else
	% read directly from local file
	X = xml2struct(source);
end

% is the XML compatible?
required_version = '1.0';
if ~isfield(X, 'tbxmanager') || ...
		~isfield(X.tbxmanager, 'Attributes') || ...
		~isfield(X.tbxmanager.Attributes, 'version') || ...
		~isequal(X.tbxmanager.Attributes.version, required_version)
	fprintf('\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
	fprintf('Run "tbxmanager selfupdate" first.\n');
	fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n');
	error('TBXMANAGER:XMLERROR', 'Cannot continue.');
end

L = [];
if ~iscell(X.tbxmanager.package)
	X.tbxmanager.package = { X.tbxmanager.package };
end
for i = 1:length(X.tbxmanager.package)
	name = lower(X.tbxmanager.package{i}.name.Text);
	versions = X.tbxmanager.package{i}.version;
	if ~iscell(versions)
		versions = { versions };
	end
	for j = 1:length(versions)
		if ~iscell(versions{j}.url)
			versions{j}.url = { versions{j}.url };
		end
		for k = 1:length(versions{j}.url)
			tbx.name = name;
			tbx.version = versions{j}.id.Text;
			tbx.date = versions{j}.date.Text;
			tbx.url = versions{j}.url{k}.Text;
			tbx.arch = lower(versions{j}.url{k}.Attributes.arch);
			if isempty(L)
				L = tbx;
			else
				L = [L tbx];
			end
		end
	end
end
end

%%
function List = tbx_listInstalled
% Returns list of installed toolboxes
%
% The list is returned as an array of structures:
%     name: short toolbox name
%  version: version id
%     arch: architecture

Setup = tbx_setup;
List = [];

toolboxes = tbx_list_dirs(Setup.tbxdir);
for it = 1:length(toolboxes)
	tbxdir = [Setup.tbxdir filesep toolboxes{it}];
	versions = tbx_list_dirs(tbxdir);
	for iv = 1:length(versions)
		[archs, dates] = tbx_list_dirs([tbxdir filesep versions{iv}]);
		for ia = 1:length(archs)
			L.name = toolboxes{it};
			L.version = versions{iv};
			L.arch = archs{ia};
			L.date = dates{ia};
			if isempty(List)
				List = L;
			else
				List(end+1) = L;
			end
		end
	end
end

end

%%
function [out, dates] = tbx_list_dirs(d)
% Helper to list all subdirectories of directory 'd'

dirs = dir(d);
out = {};
dates = {};
for i = 1:length(dirs)
	if dirs(i).isdir && ~isequal(dirs(i).name, '.') && ...
			~isequal(dirs(i).name, '..');
		out{end+1} = dirs(i).name;
		dates{end+1} = dirs(i).date;
	end
end

end

%%
function S = tbx_n2s(N)
% Converts "name:version:arch" into a structure

if isa(N, 'struct')
	S = N;
else
	% parse string
	colpos = find(N==':');
	if length(colpos)==0
		S.name = N;
		S.version = '';
		S.arch = '';
	elseif length(colpos)==1
		S.name = N(1:colpos-1);
		S.version = N(colpos+1:end);
		S.arch = '';
	elseif length(colpos)==2
		S.name = N(1:colpos(1)-1);
		S.version = N(colpos(1)+1:colpos(2)-1);
		S.arch = N(colpos(2)+1:end);
	else
		error('TBXMANAGER:BADCOMMAND', 'Malformed string, must be in "name:version:arch" format.');
	end
end

end

%%
function Enabled = tbx_loadEnabled
% Loads list of enabled toolboxes

Setup = tbx_setup;
Enabled = [];
if exist(Setup.enabledfile, 'file')
	s = textscan(fileread(Setup.enabledfile), '%s');
	if ~isempty(s)
		for i = 1:length(s{1})
			Enabled = [Enabled tbx_n2s(s{1}{i})];
		end
	end
end

end

%%
function tbx_writeEnabled(Enabled)
% writes list of enabled toolboxes

Setup = tbx_setup;
fid = fopen(Setup.enabledfile, 'w');
if fid < 0
	error('TBXMANAGER:FILEERROR', 'Couldn''t open %s for writing.', fname);
end
for i = 1:length(Enabled)
	fprintf(fid, '%s\n', tbx_s2n(Enabled(i)));
end
fclose(fid);

end

%%
function tbx_registerDisabled(Toolbox)
% Registers the toolbox as enabled

% sanitize the Toolbox structure
Toolbox = tbx_n2s(tbx_s2n(Toolbox));

Enabled = tbx_loadEnabled;
% prune any version of this toolbox from the list
keep = true(1, length(Enabled));
for i = 1:length(Enabled)
	keep(i) = ~isequal(Enabled(i), Toolbox);
end
tbx_writeEnabled(Enabled(keep));

end

%%
function tbx_registerEnabled(Toolbox)
% Registers the toolbox as enabled

% sanitize the Toolbox structure
Toolbox = tbx_n2s(tbx_s2n(Toolbox));

Enabled = tbx_loadEnabled;
% prune any previous versions of this toolbox from the list of enabled
% toolboxes
keep = true(1, length(Enabled));
for i = 1:length(Enabled)
	keep(i) = ~isequal(Enabled(i).name, Toolbox.name);
end
Enabled = [Enabled(keep) Toolbox];
tbx_writeEnabled(Enabled);

end

%%
function tbx_restorePath(args)
% Restores path to all previously active toolboxes

Enabled = tbx_loadEnabled;
for i = 1:length(Enabled)
	tbx_addPath(Enabled(i));
end

end

%%
function tbx_rmPath(Toolbox)
% Removes the given toolbox from MATLAB path
%
% Specification of the input structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

if ~tbx_isInstalled(Toolbox)
	error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not installed.', tbx_s2n(Toolbox));
end

% remove any previous instances of this toolbox from the path
archdir = tbx_installationDir(Toolbox);
w = warning; warning('off');
rmpath(genpath(archdir));
warning(w);
rehash pathreset

fprintf('Toolbox "%s" removed from the Matlab path.\n', tbx_s2n(Toolbox));

tbx_registerDisabled(Toolbox);

end

%%
function N = tbx_s2n(Toolbox)
% Converts toolbox' data into a compact string
%
% Specification of the input structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

N = [Toolbox.name ':' Toolbox.version ':' Toolbox.arch];

end

%%
function tbx_uninstall(Toolbox)
% Uninstalls a given toolbox
%
% The toolbox to be uninstalled is described by a structure:
%     name: short toolbox name
%  version: version id
%     arch: architecture

if ~tbx_isInstalled(Toolbox)
	error('TBXMANAGER:BADCOMMAND', 'Toolbox "%s" is not installed.', tbx_s2n(Toolbox));
end

% Delete the arch directory
[archdir, versiondir, basedir] = tbx_installationDir(Toolbox);
fprintf('Removing directory "%s"...\n', archdir);
rmdir(archdir, 's');

% Did we delete the last architecture of the version?
archs = tbx_list_dirs(versiondir);
if isempty(archs)
	% No more architectures, we can delete the whole version
	fprintf('Removing directory "%s"...\n', versiondir);
	rmdir(versiondir, 's');
	% Did we delete all versions?
	vers = tbx_list_dirs(basedir);
	if isempty(vers)
		% No more versions, delete the whole toolbox
		fprintf('Removing directory "%s"...\n', basedir);
		rmdir(basedir, 's');
	end
end
fprintf('Toolbox "%s" uninstalled.\n', Toolbox.name);

end

%%
function answer = tbx_expandChoice(cmd, choices)
% returns element of cell array "choices" that start with the string "cmd"

candidates = {};
if ~iscell(choices)
	choices = { choices };
end
for i = 1:length(choices)
	if length(choices{i}) >= length(cmd)
		if isequal(choices{i}(1:length(cmd)), cmd)
			candidates{end+1} = choices{i};
		end
	end
end

if length(candidates)==1
	% unambiguous choice
	answer = candidates{1};
else
	fprintf('\nYou choice "%s" is ambiguous. Possible matches are:\n', cmd);
	for i = 1:length(candidates)
		fprintf('\t%s\n', candidates{i});
	end
	fprintf('\n');
	error('TBXMANAGER:BADCOMMAND', ...
		'Ambiguous choice, please refine your input.');
end

end

%%
function [ s ] = xml2struct( file )
%Convert xml file into a MATLAB structure
% [ s ] = xml2struct( file )
%
% A file containing:
% <XMLname attrib1="Some value">
%   <Element>Some text</Element>
%   <DifferentElement attrib2="2">Some more text</Element>
%   <DifferentElement attrib3="2" attrib4="1">Even more text</DifferentElement>
% </XMLname>
%
% Will produce:
% s.XMLname.Attributes.attrib1 = "Some value";
% s.XMLname.Element.Text = "Some text";
% s.XMLname.DifferentElement{1}.Attributes.attrib2 = "2";
% s.XMLname.DifferentElement{1}.Text = "Some more text";
% s.XMLname.DifferentElement{2}.Attributes.attrib3 = "2";
% s.XMLname.DifferentElement{2}.Attributes.attrib4 = "1";
% s.XMLname.DifferentElement{2}.Text = "Even more text";
%
% Please note that the following characters are substituted
% '-' by '_dash_', ':' by '_colon_' and '.' by '_dot_'
%
% Written by W. Falkena, ASTI, TUDelft, 21-08-2010
% Attribute parsing speed increased by 40% by A. Wanner, 14-6-2011
% Added CDATA support by I. Smirnov, 20-3-2012
%
% Modified by X. Mo, University of Wisconsin, 12-5-2012

if (nargin < 1)
	clc;
	help xml2struct
	return
end

if isa(file, 'org.apache.xerces.dom.DeferredDocumentImpl') || isa(file, 'org.apache.xerces.dom.DeferredElementImpl')
	% input is a java xml object
	xDoc = file;
else
	%check for existance
	if (exist(file,'file') == 0)
		%Perhaps the xml extension was omitted from the file name. Add the
		%extension and try again.
		if (isempty(strfind(file,'.xml')))
			file = [file '.xml'];
		end
		
		if (exist(file,'file') == 0)
			error('TBXMANAGER:FILEERROR', ['The file ' file ' could not be found']);
		end
	end
	%read the xml file
	xDoc = xmlread(file);
end

%parse xDoc into a MATLAB structure
s = parseChildNodes(xDoc);

end

% ----- Subfunction parseChildNodes -----
function [children,ptext,textflag] = parseChildNodes(theNode)
% Recurse over node children.
children = struct;
ptext = struct; textflag = 'Text';
if hasChildNodes(theNode)
	childNodes = getChildNodes(theNode);
	numChildNodes = getLength(childNodes);
	
	for count = 1:numChildNodes
		theChild = item(childNodes,count-1);
		[text,name,attr,childs,textflag] = getNodeData(theChild);
		
		if (~strcmp(name,'#text') && ~strcmp(name,'#comment') && ~strcmp(name,'#cdata_dash_section'))
			%XML allows the same elements to be defined multiple times,
			%put each in a different cell
			if (isfield(children,name))
				if (~iscell(children.(name)))
					%put existsing element into cell format
					children.(name) = {children.(name)};
				end
				index = length(children.(name))+1;
				%add new element
				children.(name){index} = childs;
				if(~isempty(fieldnames(text)))
					children.(name){index} = text;
				end
				if(~isempty(attr))
					children.(name){index}.('Attributes') = attr;
				end
			else
				%add previously unknown (new) element to the structure
				children.(name) = childs;
				if(~isempty(text) && ~isempty(fieldnames(text)))
					children.(name) = text;
				end
				if(~isempty(attr))
					children.(name).('Attributes') = attr;
				end
			end
		else
			ptextflag = 'Text';
			if (strcmp(name, '#cdata_dash_section'))
				ptextflag = 'CDATA';
			elseif (strcmp(name, '#comment'))
				ptextflag = 'Comment';
			end
			
			%this is the text in an element (i.e., the parentNode)
			if (~isempty(regexprep(text.(textflag),'[\s]*','')))
				if (~isfield(ptext,ptextflag) || isempty(ptext.(ptextflag)))
					ptext.(ptextflag) = text.(textflag);
				else
					%what to do when element data is as follows:
					%<element>Text <!--Comment--> More text</element>
					
					%put the text in different cells:
					% if (~iscell(ptext)) ptext = {ptext}; end
					% ptext{length(ptext)+1} = text;
					
					%just append the text
					ptext.(ptextflag) = [ptext.(ptextflag) text.(textflag)];
				end
			end
		end
		
	end
end
end

% ----- Subfunction getNodeData -----
function [text,name,attr,childs,textflag] = getNodeData(theNode)
% Create structure of node info.

%make sure name is allowed as structure name
name = toCharArray(getNodeName(theNode))';
name = strrep(name, '-', '_dash_');
name = strrep(name, ':', '_colon_');
name = strrep(name, '.', '_dot_');

attr = parseAttributes(theNode);
if (isempty(fieldnames(attr)))
	attr = [];
end

%parse child nodes
[childs,text,textflag] = parseChildNodes(theNode);

if (isempty(fieldnames(childs)) && isempty(fieldnames(text)))
	%get the data of any childless nodes
	% faster than if any(strcmp(methods(theNode), 'getData'))
	% no need to try-catch (?)
	% faster than text = char(getData(theNode));
	text.(textflag) = toCharArray(getTextContent(theNode))';
end

end

% ----- Subfunction parseAttributes -----
function attributes = parseAttributes(theNode)
% Create attributes structure.

attributes = struct;
if hasAttributes(theNode)
	theAttributes = getAttributes(theNode);
	numAttributes = getLength(theAttributes);
	
	for count = 1:numAttributes
		%attrib = item(theAttributes,count-1);
		%attr_name = regexprep(char(getName(attrib)),'[-:.]','_');
		%attributes.(attr_name) = char(getValue(attrib));
		
		%Suggestion of Adrian Wanner
		str = toCharArray(toString(item(theAttributes,count-1)))';
		k = strfind(str,'=');
		attr_name = str(1:(k(1)-1));
		attr_name = strrep(attr_name, '-', '_dash_');
		attr_name = strrep(attr_name, ':', '_colon_');
		attr_name = strrep(attr_name, '.', '_dot_');
		attributes.(attr_name) = str((k(1)+2):(end-1));
	end
end
end
