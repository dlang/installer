#!/bin/bash

set -uexo pipefail

if [ "${OS_NAME:-}" = "linux" ]; then
    compilers=(
        dmd-2.088.1
        dmd-2.094.2
        dmd-2.097.2
        dmd-master-2020-03-10
        ldc-1.18.0
        gdc-4.9.3
        gdc-4.8.5
    )

    versions=(
        'DMD64 D Compiler v2.088.1'
        'DMD64 D Compiler v2.094.2'
        'DMD64 D Compiler v2.097.2'
        'DMD64 D Compiler v2.091.0-beta.2-master-ec39fe5'
        'LDC - the LLVM D compiler (1.18.0):'
        'gdc (crosstool-NG crosstool-ng-1.20.0-232-gc746732 - 20150825-2.066.1-58ec4c13ec) 4.9.3'
        'gdc (gdcproject.org 20161225-v2.068.2_gcc4.8) 4.8.5'
    )
    frontendVersions=(
        '2088'
        '2094'
        '2097'
        '2091'
        '2088'
        '2066'
        '2068'
    )
elif [ "${OS_NAME:-}" = "osx" ]; then
    # Since macOS 12.x, versions of DMD older than 2.099.1 do not work.
    # https://github.com/dlang/dmd/pull/13890
    compilers=(
        dmd-2.099.1
        dmd-2.100.0
        dmd-2.101.2
        ldc-1.30.0
    )

    versions=(
        'DMD64 D Compiler v2.099.1'
        'DMD64 D Compiler v2.100.0'
        'DMD64 D Compiler v2.101.2'
        'LDC - the LLVM D compiler (1.30.0):'
    )
    frontendVersions=(
        '2099'
        '2100'
        '2101'
        '2100'
    )
else
    compilers=(
        dmd-2.088.1
        dmd-2.094.2
        dmd-2.097.2
        dmd-master-2020-03-10
        ldc-1.18.0
    )

    versions=(
        'DMD64 D Compiler v2.088.1'
        'DMD64 D Compiler v2.094.2'
        'DMD64 D Compiler v2.097.2'
        'DMD64 D Compiler v2.091.0-beta.2-master-ec39fe5'
        'LDC - the LLVM D compiler (1.18.0):'
    )
    frontendVersions=(
        '2088'
        '2094'
        '2097'
        '2091'
        '2088'
    )
fi

OS=$(uname -s)
testDir=/tmp/dlang-installer-test-$UID
rm -rf "$testDir"
mkdir -m 700 "$testDir" || mkdir -p "$testDir"
export HOME=$testDir

testFile="$testDir"/test
echo "void main(){ import std.stdio; __VERSION__.writeln;}" > "${testFile}.d"

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"
    echo "Testing: $compiler"
    ./script/install.sh $compiler

    . ~/dlang/$compiler/activate
    # test compiler version
    if [[ "$compiler" == "dmd-2.064" ]] ; then
        # older dmd versions can't be run on CI
        deactivate
        ./script/install.sh uninstall $compiler
        continue
    fi

    expectedVersion="${versions[$idx]}"
    compilerVersion=$($DC --version | sed -n 1p | tr -d '\r')
    # We don't ship 64-bit binaries on Windows
    if [[ "$OS" == *_NT-* ]]; then expectedVersion=${expectedVersion/DMD64/DMD32}; fi
    test "$compilerVersion" = "$expectedVersion"
    compilerVersion=$($DMD --version | sed -n 1p | tr -d '\r')
    test "$compilerVersion" = "$expectedVersion"
    deactivate

    # Check whether the compilers have been successfully installed
    touch "$testFile".d
    source $(./script/install.sh $compiler --activate)
    ( cd "$testDir" && ${DMD} -oftest test.d )
    test "$(${testFile} | tr -d '\r')" = "${frontendVersions[$idx]}"
    rm ${testFile}
    deactivate

    source $(./script/install.sh $compiler -a)
    command -v dub >/dev/null 2>&1 || { echo >&2 "DUB hasn't been installed."; exit 1; }
    deactivate

    ./script/install.sh uninstall $compiler
done

# test resolution of latest using the remove error message
latest=(dmd dmd-beta dmd-master dmd-nightly ldc ldc-beta ldc-latest-ci gdc dmd-2018-10-14)
for compiler in "${latest[@]}"
do
    set +e
    resolved=$(./script/install.sh remove "$compiler" 2>&1)
    set -e
    if ! [[ $resolved =~ ^${compiler%-*}-(.+)$ ]]; then
        echo "Failed to resolve $compiler, got '$resolved'"
    fi
done

cmds=(install uninstall list update)
for cmd in "${cmds[@]}"
do
    ./script/install.sh --help | grep -F "$cmd" >/dev/null
    ./script/install.sh -h | grep -F "$cmd" >/dev/null
    ./script/install.sh "$cmd" --help | tr -d '\n' | grep -q "Usage\s*install.sh $cmd" >/dev/null
    ./script/install.sh "$cmd" -h | tr -d '\n' | grep -q "Usage\s*install.sh $cmd" >/dev/null
done
# remove is alias for uninstall
./script/install.sh remove --help | tr -d '\n' | grep "Usage\s*install.sh uninstall" >/dev/null
./script/install.sh remove -h | tr -d '\n' | grep "Usage\s*install.sh uninstall" >/dev/null

# test that a missing keyring gets restored - https://issues.dlang.org/show_bug.cgi?id=19100
rm ~/dlang/d-keyring.gpg
./script/install.sh dmd-2.088.1
if [ ! $(find ~/dlang/d-keyring.gpg -type f -size +8096c 2>/dev/null) ]; then
    ls -l ~/dlang/d-keyring.gpg
    echo "Invalid keyring got installed."
    exit 1
fi
./script/install.sh remove dmd-2.088.1

# check whether all installations have been uninstalled successfully
if bash script/install.sh list
then
    echo "Uninstall of the compilers failed."
    exit 1
fi

# test dmd-nightly
./script/install.sh install dmd-nightly
dmd_nightly="$(./script/install.sh list | grep dmd-nightly)"
./script/install.sh uninstall "$dmd_nightly"

# test dmd-beta
./script/install.sh install dmd-beta
dmd_beta="$(./script/install.sh list | grep dmd)"
./script/install.sh uninstall "$dmd_beta"

# check whether dmd-beta and dmd-nightly installations have been uninstalled successfully
if bash script/install.sh list
then
    echo "Uninstall of the compilers failed."
    exit 1
fi

# test in-place update
if [ "${OS_NAME:-}" != "windows" ]; then # needs bootstrapping, TODO remove after merge/deploy
    cp script/install.sh "$testDir"/
    bash "$testDir"/install.sh update --path "$testDir"
    bash "$testDir"/install.sh update -p "$testDir"
fi

if [ "${OS_NAME:-}" = "linux" ]; then
    shellcheck script/install.sh
fi
