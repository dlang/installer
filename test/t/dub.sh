#!/bin/bash

set -uexo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../
. $DIR/common.sh

compilers=(
    dub-1.10.0
    dub-1.11.0
    dmd-2.080.0,dub-1.14.0
)

versions=(
    'DUB version 1.10.0, built on '
    'DUB version 1.11.0, built on '
    'DUB version 1.14.0, built on '
)

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"

    if [[ "${TRAVIS_OS_NAME:-}" == "windows" && "$compiler" == *dub-1.14.0 ]]; then
        continue # https://github.com/dlang/dub/issues/1795
    fi

    echo "Testing: $compiler"
    "$INSTALLER" -p ~/dlang $compiler
    . $("$INSTALLER" -p ~/dlang $compiler -a)

    compilerVersion=$(dub --version | sed -n 1p | tr -d '\r')
    [[ "$compilerVersion" == "${versions[$idx]}"* ]]
    deactivate

    "$INSTALLER" -p ~/dlang uninstall $compiler
done

# test latest dub works
"$INSTALLER" -p ~/dlang dmd-2.080.0,dub
. $("$INSTALLER" -p ~/dlang $compiler -a)
if [ "${TRAVIS_OS_NAME:-}" != "windows" ]; then # https://github.com/dlang/dub/issues/1795
    dub --version
fi

deactivate
"$INSTALLER" -p ~/dlang uninstall $compiler
