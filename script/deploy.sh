#!/usr/bin/env bash

set -uexo pipefail

ROOT=$(dirname $0)

rm -f $ROOT/install.sh.sig
${GPG:-gpg2} --detach-sign $ROOT/install.sh

scp "$ROOT/install.sh" "$ROOT/install.sh.sig" digitalmars.com:/usr/local/www/dlang.org/data/
aws --profile ddo s3 cp "$ROOT/install.sh" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
aws --profile ddo s3 cp "$ROOT/install.sh.sig" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
