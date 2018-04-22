#!/bin/bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/common.sh

for file in $(find "$DIR" -name "*.sh") ; do
    if ! ( [[ "$file" == */all.sh ]] || [[ "$file" == */common.sh ]] ) ; then
        $file
    fi
done
