#!/bin/bash

set -euo pipefail
set -x

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_VERSION=2.080.1

setup_vagrant_boxes() {
    vagrant box add wilzbach/create_dmd_release-linux
    # rename
    mv ~/.vagrant.d/boxes/wilzbach-VAGRANTSLASH-create_dmd_release-linux \
        ~/.vagrant.d/boxes/create_dmd_release-linux
}

download_install_sh() {
  local mirrors location
  location="${1:-install.sh}"
  mirrors=(
    "https://dlang.org/install.sh"
    "https://downloads.dlang.org/other/install.sh"
    "https://nightlies.dlang.org/install.sh"
  )
  if [ -f "$location" ] ; then
      return
  fi
  for i in {0..4}; do
    for mirror in "${mirrors[@]}" ; do
        if curl -fsS -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 "$mirror" -o "$location" ; then
            break 2
        fi
    done
    sleep $((1 << i))
  done
}
install_d() {
  local install_sh="install.sh"
  download_install_sh "$install_sh"
  CURL_USER_AGENT="$CURL_USER_AGENT" bash "$install_sh" "$1" -a
}
add_d_keyring(){
    export GNUPGHOME="$PWD/.gnupg"
    mkdir -p .gnupg
    cp ~/dlang/d-keyring.gpg .gnupg/pubring.gpg
}

# bootstrapping
setup_vagrant_boxes
source $(install_d "dmd-$DMD_VERSION")
add_d_keyring

cd create_dmd_release
rdmd -g ./build_all.d --platforms=linux v2.080.1 master
VBoxManage --version
