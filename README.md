# Toolbox Manager

Toolbox Manager is a package manager for Matlab. In short, it's to Matlab what `apt-get` is to Linux.

This repository contains the Matlab command-line client that allows to install and update toolboxes. The central repository of available packages is hosted at [www.tbxmanager.com](http://www.tbxmanager.com).

## Installation:

```matlab
urlwrite('http://www.tbxmanager.com/tbxmanager.m', 'tbxmanager.m');
tbxmanager
savepath
```

Edit/create `startup.m` in your Matlab startup folder and put the following line there:

```
tbxmanager restorepath
```

Alternatively, run this command manually every time you start Matlab.

## Installation of packages

```
tbxmanager install package_name
```

## Updating of packages

```
tbxmanager update
```

## List available packages

```
tbxmanager show available
```

## All supported commands

```
tbxmanager install package1 package2 ...
tbxmanager show enabled
tbxmanager show installed
tbxmanager show available
tbxmanager show sources
tbxmanager update
tbxmanager update package1 package2 ...
tbxmanager restorepath
tbxmanager generatepath
tbxmanager enable package1 package2 ...
tbxmanager disable package1 package2 ...
tbxmanager uninstall package1 package2 ...
tbxmanager source add URL
tbxmanager source remove URL
tbxmanager selfupdate
tbxmanager require package1 package2 ...
```
