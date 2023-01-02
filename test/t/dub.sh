#!/bin/bash

set -uexo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../
. $DIR/common.sh

compilers=(
    dub-1.21.0
    dub-1.22.0
    dmd-2.088.1,dub-1.23.0
)

versions=(
    'DUB version 1.21.0, built on '
    'DUB version 1.22.0, built on '
    'DUB version 1.23.0, built on '
)

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"

    if [[ "${OS_NAME:-}" == "windows" && "$compiler" == *dub-1.23.0 ]]; then
        continue # https://github.com/dlang/dub/issues/1795
    fi

    echo "Testing: $compiler"
    "$INSTALLER" $INSTALLER_ARGS $compiler
    . $("$INSTALLER" $compiler -a)

    compilerVersion=$(dub --version | sed -n 1p | tr -d '\r')
    [[ "$compilerVersion" == "${versions[$idx]}"* ]]
    deactivate

    "$INSTALLER" uninstall $compiler
done

# test latest dub works
"$INSTALLER" dmd-2.088.1,dub
. $("$INSTALLER" $compiler -a)
if [ "${OS_NAME:-}" != "windows" ]; then # https://github.com/dlang/dub/issues/1795
    dub --version
fi

deactivate
"$INSTALLER" uninstall $compiler
