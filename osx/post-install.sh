#!/usr/bin/env bash

##
# Author:: Jacob Carlborg
# Version:: Initial created: 2009
# License:: Public Domain
#

set -e

function sudo_ln {
  sudo ln -sf "$@"
}

function sudo_mkdir {
  sudo mkdir -p "$@"
}

install_path=/Library/D/dmd
target_path=/usr/local
bin_path=$target_path/bin
man_path=$target_path/share/man
man1_path=$man_path/man1
man5_path=$man_path/man5

sudo_mkdir $bin_path
sudo_mkdir $man1_path
sudo_mkdir $man5_path

sudo_ln $install_path/bin/ddemangle $bin_path/ddemangle
sudo_ln $install_path/bin/dmd $bin_path/dmd
sudo_ln $install_path/bin/dmd.conf $bin_path/dmd.conf
sudo_ln $install_path/bin/dumpobj $bin_path/dumpobj
sudo_ln $install_path/bin/dustmite $bin_path/dustmite
sudo_ln $install_path/bin/obj2asm $bin_path/obj2asm
sudo_ln $install_path/bin/rdmd $bin_path/rdmd
sudo_ln $install_path/man/man1/dmd.1 $man1_path/dmd.1
sudo_ln $install_path/man/man1/dumpobj.1 $man1_path/dumpobj.1
sudo_ln $install_path/man/man1/obj2asm.1 $man1_path/obj2asm.1
sudo_ln $install_path/man/man1/rdmd.1 $man1_path/rdmd.1
sudo_ln $install_path/man/man5/dmd.conf.5 $man5_path/dmd.conf.5
