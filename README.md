D installers
============

[![CI status](https://travis-ci.org/dlang/installer.svg?branch=master)](https://travis-ci.org/dlang/installer/)
[![Bugzilla Issues](https://img.shields.io/badge/issues-Bugzilla-green.svg)](https://issues.dlang.org/buglist.cgi?component=installer&list_id=220147&product=D&resolution=---)

This repository hosts scripts to build DMD installers and packages.

To download a ready-built D installer or package, please visit the
[dlang.org downloads page](http://dlang.org/download.html).

To learn more about the install script, please visit the
[`install.sh` documentation](https://dlang.org/install.html).

To report a problem or browse the list of open bugs, please visit the
[bug tracker](http://issues.dlang.org/).

AppVeyor Windows build
----------------------

[![Build status](https://ci.appveyor.com/api/projects/status/415wrv2m0av1b62w?svg=true)](https://ci.appveyor.com/project/4wil/installer)

All pre-built Windows binaries are built on AppVeyor.
However, due to their heavy build time, these Windows binary builds have been moved to their own branch.
To bump the version, make a pull request against the respective branch:

- [MinGW libs](https://github.com/dlang/installer/tree/build-mingw-libs)
- [LLD](https://github.com/dlang/installer/tree/build-lld) - the LLVM linker
- [Curl](https://github.com/dlang/installer/tree/build-curl)
