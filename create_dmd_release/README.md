Building a DMD release
======================

Setup all Vagrant boxes
-----------------------

- see `create_vagrant_boxes` for Linux and FreeBSD
- refer to the header of `build_all.d` for Windows and OSX)

Building a release
------------------

```
./build_all.d <old-dmd-version> <git-branch-or-tag> [--skip-docs]
./build_all.d v2.080.0 v2.080.1
```
