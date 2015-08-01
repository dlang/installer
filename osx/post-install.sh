#!/usr/bin/env bash

##
# Author:: Jacob Carlborg
# Version:: Initial created: 2009
# License:: Public Domain
#

install_path=/Library/D/dmd
target_path=/usr/local
bin_path=$target_path/bin
man_path=$target_path/share/man
man1_path=$man_path/man1
man5_path=$man_path/man5

mkdir -p $bin_path
mkdir -p $man1_path
mkdir -p $man5_path

ln -sf $install_path/bin/ddemangle $bin_path/ddemangle
ln -sf $install_path/bin/dmd $bin_path/dmd
ln -sf $install_path/bin/dmd.conf $bin_path/bin/dmd.conf
ln -sf $install_path/bin/dumpobj $bin_path/bin/dumpobj
ln -sf $install_path/bin/dustmite $bin_path/bin/dustmite
ln -sf $install_path/bin/obj2asm $bin_path/bin/obj2asm
ln -sf $install_path/bin/rdmd $bin_path/bin/rdmd
ln -sf $install_path/man/man1/dmd.1 $man1_path/dmd.1
ln -sf $install_path/man/man1/dumpobj.1 $man1_path/dumpobj.1
ln -sf $install_path/man/man1/obj2asm.1 $man1_path/obj2asm.1
ln -sf $install_path/man/man1/rdmd.1 $man1_path/rdmd.1
ln -sf $install_path/man/man5/dmd.conf.5 $man5_path/dmd.conf.5
