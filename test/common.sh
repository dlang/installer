#!/bin/bash

set -eu -o pipefail

ROOT="$DIR/../"
INSTALLER="$ROOT/script/install.sh"
INSTALLER_ARGS=""
if [ "${OS_NAME}" == "osx" ] ; then
    INSTALLER_ARGS="--arch x86_64"
fi


assert() {
    actual="$1"
    expected="$2"
    if [ "$actual" != "$expected" ] ; then
        echo "Actual: $actual"
        echo "Expected: $expected"
        exit 1
    fi
}

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR
