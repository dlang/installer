#!/bin/bash

set -uexo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../
. $DIR/common.sh

priorDMD=$(dmd --version || echo "no dmd")

. $(./script/install.sh install dmd-2.082.1 -a)
test "$(dmd --version | grep -oE '[^ ]+$' | head -n1 | tr -d '\r')" = "v2.082.1"

. $(./script/install.sh install dmd-2.083.1 -a)
test "$(dmd --version | grep -oE '[^ ]+$' | head -n1 | tr -d '\r')" = "v2.083.1"

deactivate

test "$(dmd --version || echo "no dmd")" = "$priorDMD"
