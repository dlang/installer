#!/bin/bash

set -uexo pipefail

compilers=(
    dmd-2.069.2
    dmd-2.071.2
    dmd-2.077.1
    dmd-master-2018-10-14
    ldc-1.4.0
)

versions=(
    'DMD64 D Compiler v2.069.2'
    'DMD64 D Compiler v2.071.2'
    'DMD64 D Compiler v2.077.1'
    'DMD64 D Compiler v2.082.1-master-54b676b'
    'LDC - the LLVM D compiler (1.4.0):'
)

frontendVersions=(
    '2069'
    '2071'
    '2077'
    '2082'
    '2074'
)

if [ "${TRAVIS_OS_NAME:-}" != "osx" ]; then
    compilers+=(
        gdc-4.9.3
        gdc-4.8.5
    )

    versions+=(
        'gdc (crosstool-NG crosstool-ng-1.20.0-232-gc746732 - 20150825-2.066.1-58ec4c13ec) 4.9.3'
        'gdc (gdcproject.org 20161225-v2.068.2_gcc4.8) 4.8.5'
    )
    frontendVersions+=(
        '2066'
        '2068'
    )
fi

testFile=/tmp/$(mktemp tmp_XXXXXXXX)
echo "void main(){ import std.stdio; __VERSION__.writeln;}" > "${testFile}.d"

for idx in "${!compilers[@]}"
do
    compiler="${compilers[$idx]}"
    echo "Testing: $compiler"
    ./script/install.sh $compiler

    . ~/dlang/$compiler/activate
    compilerVersion=$($DC --version | sed -n 1p)
    test "$compilerVersion" = "${versions[$idx]}"
    compilerVersion=$($DMD --version | sed -n 1p)
    test "$compilerVersion" = "${versions[$idx]}"
    deactivate

    # Check whether the compilers have been successfully installed
    touch "$testFile".d
    source $(./script/install.sh $compiler --activate)
    ${DMD} "-of${testFile}" "${testFile}.d"
    test "$(${testFile})" = "${frontendVersions[$idx]}"
    rm ${testFile}
    deactivate

    source $(./script/install.sh $compiler -a)
    command -v dub >/dev/null 2>&1 || { echo >&2 "DUB hasn't been installed."; exit 1; }
    deactivate

    ./script/install.sh uninstall $compiler
done

# test resolution of latest using the remove error message
latest=(dmd dmd-beta dmd-master dmd-nightly ldc ldc-beta gdc dmd-2018-10-14)
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
./script/install.sh dmd-2.081.2
if [ ! $(find ~/dlang/d-keyring.gpg -type f -size +8096c 2>/dev/null) ]; then
    ls -l ~/dlang/d-keyring.gpg
    echo "Invalid keyring got installed."
    exit 1
fi
./script/install.sh remove dmd-2.081.2

# check whether all installations have been uninstalled successfully
if bash script/install.sh list
then
    echo "Uninstall of the compilers failed."
    exit 1
fi

# test in-place update
bash script/install.sh update --path "$PWD/script"
bash script/install.sh update -p "$PWD/script"
# reset script
git checkout -- script/install.sh

if [ "${TRAVIS_OS_NAME:-}" != "osx" ]; then
    shellcheck script/install.sh
fi
