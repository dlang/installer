#!/bin/bash

set -uexo pipefail

declare -A compilers=(
 ["dmd-2.069.2"]="DMD64 D Compiler v2.069.2"
 ["dmd-2.071.2"]="DMD64 D Compiler v2.071.2"
 ["dmd-2016-10-19"]="DMD64 D Compiler v2.073.0-master-878b882"
 ["dmd-master-2016-10-24"]="DMD64 D Compiler v2.073.0-master-ab9d712"
 ["ldc-1.4.0"]="LDC - the LLVM D compiler (1.4.0):"
 ["gdc-4.9.3"]="gdc (crosstool-NG crosstool-ng-1.20.0-232-gc746732 - 20150825-2.066.1-58ec4c13ec) 4.9.3"
 ["gdc-4.8.5"]="gdc (gdcproject.org 20161225-v2.068.2_gcc4.8) 4.8.5"
)

for compiler in "${!compilers[@]}"
do
    echo "Testing: $compiler"
    ./script/install.sh $compiler

    . ~/dlang/$compiler/activate
    compilerVersion=$($DC --version | head -n1)
    test "$compilerVersion" = "${compilers[$compiler]}"
    compilerVersion=$($DMD --version | head -n1)
    test "$compilerVersion" = "${compilers[$compiler]}"
    deactivate

    source $(./script/install.sh $compiler --activate)
    deactivate
    source $(./script/install.sh $compiler -a)
    deactivate

    ./script/install.sh uninstall $compiler
done

# test resolution of latest using the remove error message
latest=(dmd dmd-beta dmd-master dmd-nightly ldc ldc-beta gdc)
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
    ./script/install.sh --help | grep -qF "$cmd"
    ./script/install.sh -h | grep -qF "$cmd"
    ./script/install.sh "$cmd" --help | tr -d '\n' | grep -q "Usage\s*install.sh $cmd"
    ./script/install.sh "$cmd" -h | tr -d '\n' | grep -q "Usage\s*install.sh $cmd"
done
# remove is alias for uninstall
./script/install.sh remove --help | tr -d '\n' | grep -q "Usage\s*install.sh uninstall"
./script/install.sh remove -h | tr -d '\n' | grep -q "Usage\s*install.sh uninstall"

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
