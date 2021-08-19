#!/bin/bash

set -eux -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../
. $DIR/common.sh

compilers=(
    dmd-2.088.1
    dmd-master-2020-03-10
    ldc-1.18.0
    dmd-2.088.1,dub-1.21.0
)
ROOT="$HOME/dlang"
versions_dmd=()
versions_dc=()
versions_dub=()

if [ "${OS_NAME}" == "linux" ] ; then
    # No GDC binaries on OSX
    compilers+=(
        "gdc-4.8.5"
    )
    versions_dmd+=(
        "$ROOT/dmd-2.088.1/linux/bin64/dmd"
        "$ROOT/dmd-master-2020-03-10/linux/bin64/dmd"
        "$ROOT/ldc-1.18.0/bin/ldmd2"
        "$ROOT/dmd-2.088.1/linux/bin64/dmd"
        "$ROOT/gdc-4.8.5/bin/gdmd"
    )
    versions_dc+=(
        "$ROOT/dmd-2.088.1/linux/bin64/dmd"
        "$ROOT/dmd-master-2020-03-10/linux/bin64/dmd"
        "$ROOT/ldc-1.18.0/bin/ldc2"
        "$ROOT/dmd-2.088.1/linux/bin64/dmd"
        "$ROOT/gdc-4.8.5/bin/gdc"
    )
    versions_dub+=(
        "$ROOT/dmd-2.088.1/linux/bin64/dub"
        "$ROOT/dmd-master-2020-03-10/linux/bin64/dub"
        "$ROOT/ldc-1.18.0/bin/dub"
        "$ROOT/dub-1.21.0/dub"
        "$ROOT/dub/dub"
    )
elif [ "${OS_NAME}" == "osx" ]; then
    versions_dmd+=(
        "$ROOT/dmd-2.088.1/osx/bin/dmd"
        "$ROOT/dmd-master-2020-03-10/osx/bin/dmd"
        "$ROOT/ldc-1.18.0/bin/ldmd2"
        "$ROOT/dmd-2.088.1/osx/bin/dmd"
    )
    versions_dc+=(
        "$ROOT/dmd-2.088.1/osx/bin/dmd"
        "$ROOT/dmd-master-2020-03-10/osx/bin/dmd"
        "$ROOT/ldc-1.18.0/bin/ldc2"
        "$ROOT/dmd-2.088.1/osx/bin/dmd"
    )
    versions_dub+=(
        "$ROOT/dmd-2.088.1/osx/bin/dub"
        "$ROOT/dmd-master-2020-03-10/osx/bin/dub"
        "$ROOT/ldc-1.18.0/bin/dub"
        "$ROOT/dub-1.21.0/dub"
    )
elif [ "${OS_NAME}" == "windows" ]; then
    versions_dmd+=(
        "$ROOT/dmd-2.088.1/windows/bin/dmd"
        "$ROOT/dmd-master-2020-03-10/windows/bin/dmd"
        "$ROOT/ldc-1.18.0/bin/ldmd2"
        "$ROOT/dmd-2.088.1/windows/bin/dmd"
    )
    versions_dc+=(
        "$ROOT/dmd-2.088.1/windows/bin/dmd"
        "$ROOT/dmd-master-2020-03-10/windows/bin/dmd"
        "$ROOT/ldc-1.18.0/bin/ldc2"
        "$ROOT/dmd-2.088.1/windows/bin/dmd"
    )
    versions_dub+=(
        "$ROOT/dmd-2.088.1/windows/bin/dub"
        "$ROOT/dmd-master-2020-03-10/windows/bin/dub"
        "$ROOT/ldc-1.18.0/bin/dub"
        "$ROOT/dub-1.21.0/dub"
    )
else
    echo "Unknown platform: ${OS_NAME}"
    exit 1
fi

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"
    echo "Testing: $compiler"
    assert "$("$INSTALLER" get-path --dmd "$compiler" --install)" "${versions_dmd[$idx]}"
    assert "$("$INSTALLER" get-path "$compiler" --dmd)" "${versions_dmd[$idx]}"
    assert "$("$INSTALLER" get-path "$compiler")" "${versions_dc[$idx]}"
    assert "$("$INSTALLER" get-path --dub "$compiler")" "${versions_dub[$idx]}"
    $INSTALLER uninstall "$compiler"
done

# Test for conflicts
flag_combinations=(
    "get-path --dmd --dub"
    "install --dmd"
    "install --dub"
    "install --install"
    "update --dub"
)
for flags in "${flag_combinations[@]}" ; do
    IFS=" " read -r -a flagArray <<< "$flags"
    out=$(! "$INSTALLER" "${flagArray[@]}" 2>&1)
    if ! (echo "$out" | grep -q -E "(conflicts|ERROR)") ; then
        echo "ERROR: $flags was valid"
        exit 1
    fi
done

################################################################################
# assert error without --install
################################################################################
out=$(! "$INSTALLER" get-path dmd-2.077.0 2>&1)
echo "$out" | grep -q "not installed"

################################################################################
# check installations without dub
################################################################################

$INSTALLER install dmd-2.066.0
rm -rf ~/dlang/dub # manually uninstall dub
out=$(! "$INSTALLER" get-path --dub dmd-2.066.0 2>&1)
echo "$out" | grep -q "DUB is not installed"
$INSTALLER uninstall dmd-2.066.0

################################################################################
# check dub installation
################################################################################

# check errors if dub is installed
$INSTALLER uninstall dub-1.22.0 || echo "dub-1.22.0 wasn't installed"
out=$(! "$INSTALLER" get-path dub-1.22.0 2>&1)
echo "$out" | grep -q "not installed"

out=$(! "$INSTALLER" get-path --dmd dub-1.22.0 2>&1)
echo "$out" | grep -q "not installed"

out=$(! "$INSTALLER" get-path dub-1.22.0 --dub 2>&1)
echo "$out" | grep -q "not installed"

# dmd is installed, but not dub
$INSTALLER install dmd-2.079.0
out=$(! "$INSTALLER" get-path dmd-2.079.0,dub-1.22.0 --dub 2>&1)
echo "$out" | grep -q "not installed"
$INSTALLER uninstall dmd-2.079.0

# errors when requesting a compiler with dub
out=$(! "$INSTALLER" get-path --install dub-1.22.0 2>&1 | tail -n1)
assert "$out" "ERROR: DUB is not a compiler."

out=$(! "$INSTALLER" get-path --dmd dub-1.22.0 2>&1)
assert "$out" "ERROR: DUB is not a compiler."

# dub with --dub
out=$("$INSTALLER" get-path dub-1.22.0 --dub 2>&1)
assert "$out" "$ROOT/dub-1.22.0/dub"

$INSTALLER uninstall dub-1.22.0
