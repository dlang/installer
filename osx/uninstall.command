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

function sudo_rm {
  sudo -p "Please give your password for uninstallation: " rm -rf "$@"
}

function remove_if_empty {
  dir=$1
  test -d $dir && find $dir -mindepth 1 -print -quit | (! grep -q .) && sudo_rm $dir
}

function remove_recursively {
  start=$1
  end=$2
  path=$start

  while [ $path != $end ]; do
    remove_if_empty $path
    path=`dirname $path`
  done
}

function remove_dmd {
  sudo_rm $install_path
}

function remove_symlinks {
  sudo_rm $bin_path/ddemangle \
    $bin_path/dmd \
    $bin_path/dmd.conf \
    $bin_path/dumpobj \
    $bin_path/dustmite \
    $bin_path/dub \
    $bin_path/obj2asm \
    $bin_path/rdmd \
    $man1_path/dmd.1 \
    $man1_path/dumpobj.1 \
    $man1_path/obj2asm.1 \
    $man1_path/rdmd.1 \
    $man5_path/dmd.conf.5

  remove_if_empty $man1_path
  remove_if_empty $man5_path
}

function remove_non_standard_paths {
  remove_recursively $install_path /Library
  remove_if_empty $bin_path
  remove_recursively $man_path /usr
}

remove_dmd
remove_symlinks
remove_non_standard_paths

echo "Uninstallation complete!"
