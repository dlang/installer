DMD binary releases are now built with LDC

Binary releases for Linux, OSX, and FreeBSD are now built with
LDC. This follows the switch to LDC as host compiler for Windows
releases with 2.091.0.

Building DMD with LDC should provide a significant speedup of the compiler (20-30%).

This change comes with the following limitations:
- no more FreeBSD 32-bit binary releases (no 32-bit LDC host compiler)
- additional binary tools copied over from previous dmd releases are no longer included
  (see [c0de0295e6b1f9a802bb04a97cca9f06c5b0dccd](https://github.com/dlang/installer/commit/c0de0295e6b1f9a802bb04a97cca9f06c5b0dccd) (optlink still included))
  They are still available via https://digitalmars.com/ or from older dmd releases.
