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

Prebuilt Windows libaries
-------------------------

The following binaries are pre-built:
- LLD (`windows/build_lld.bat`) - the LLVM linker
- MinGW (`windows/build_mingw.bat`)
- Curl (`windows/build_curl.bat`) - built on its own [branch](https://github.com/dlang/installer/tree/build-curl)

Upgrading these libraries requires three steps:

### 1) Build the new application/library

- bump the version of the library/application in [`azure-pipelines.yml`](azure-pipelines.yml)
- update the `sha256sums` file in the respective in `windows` (e.g. `windows/build_lld.sha256sums`)
- submit a PR

### 2) Upload the artifact to downloads.dlang.org

- upload the artifact to downloads.dlang.org
- rebuilt the site index of downloads.dlang.org
- ping a maintainer if you don't have the rights)

### 3) Bump the used application/library version

Typically this requires a PR against [`create_dmd_release/build_all.d`](create_dmd_release/build_all.d).

x
