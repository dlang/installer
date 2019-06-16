#!/bin/bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

for file in $(find "$DIR/t" -name "*.sh") ; do
    echo "---- Testing: $file"
    $file
done
