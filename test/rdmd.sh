#!/bin/bash

set -uexo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/common.sh

compilers=(
    dmd-2.079.0
    ldc-1.8.0
    gdc-4.8.5
)

frontends=(
    '2079L'
    '2078L'
    '2068L'
)

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"
    echo "Testing: $compiler"
    "$INSTALLER" $compiler

    . ~/dlang/$compiler/activate
    echo "pragma(msg, __VERSION__);" > test.d
    # test vanilla rdmd
    compilerFrontend=$(tail -n1 <(rdmd --force -c test.d 2>&1))
    test "$compilerFrontend" = "${frontends[$idx]}"

    # test $RDMD
    compilerFrontend=$(tail -n1 <("$RDMD" --force -c test.d 2>&1))
    test "$compilerFrontend" = "${frontends[$idx]}"
    deactivate

    # cleanup
    rm -rf test.d test.o
    "$INSTALLER" uninstall $compiler
done
