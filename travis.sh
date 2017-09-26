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
    bash script/install.sh $compiler
    source ~/dlang/$compiler/activate

    # simple check whether the installation was successful
    if [[ $compiler =~ dmd ]]
    then
        compilerVersion=$(dmd --version | head -n1)
    elif [[ $compiler =~ ldc ]]
    then
        compilerVersion=$(ldc2 --version | head -n1)
    elif [[ $compiler =~ gdc ]]
    then
        compilerVersion=$(gdc --version | head -n1)
    fi

    if [ "$compilerVersion" != "${compilers[$compiler]}" ]
    then
        echo "Mismatch - expected: '${compilers[$compiler]}', received: $compilerVersion"
        exit 1
    fi

    deactivate
    bash script/install.sh uninstall $compiler
done

# check whether all installations have been uninstalled successfully
if bash script/install.sh list
then
    echo "Uninstall of the compilers failed."
    exit 1
fi

bash script/install.sh update --path "$PWD/script"

if [ "${TRAVIS_OS_NAME:-}" != "osx" ]; then
    shellcheck script/install.sh
fi
