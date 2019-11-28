#!/bin/bash

set -uexo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../
. $DIR/common.sh

compilers=(
    dub-1.10.0
    dub-1.11.0
    dmd-2.079.0,dub-1.12.0
)

versions=(
    'DUB version 1.10.0, built on Jul  3 2018'
    'DUB version 1.11.0, built on Sep  1 2018'
    'DUB version 1.12.0, built on Nov  1 2018'
)

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"
    echo "Testing: $compiler"
    "$INSTALLER" $compiler
    . $("$INSTALLER" $compiler -a)

    compilerVersion=$(dub --version | sed -n 1p)
    test "$compilerVersion" = "${versions[$idx]}"
    deactivate

    "$INSTALLER" uninstall $compiler
done

# test latest dub works
"$INSTALLER" dmd-2.079.0,dub
. $("$INSTALLER" $compiler -a)
dub --version

deactivate
"$INSTALLER" uninstall $compiler
