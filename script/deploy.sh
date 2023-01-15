#!/usr/bin/env bash

set -uexo pipefail

ROOT=$(dirname $0)

function awsb2
{
    region=$(aws --profile ddo configure list | awk '$1 == "region" { print $2 }')
    aws --endpoint-url="https://s3.${region}.backblazeb2.com" $@
}

rm -f $ROOT/install.sh.sig
${GPG:-gpg2} --detach-sign $ROOT/install.sh

scp "$ROOT/install.sh" "$ROOT/install.sh.sig" digitalmars.com:/usr/local/www/dlang.org/data/
awsb2 --profile ddo s3 cp "$ROOT/install.sh" s3://downloads-dlang-org/other/ --acl public-read --cache-control max-age=604800
awsb2 --profile ddo s3 cp "$ROOT/install.sh.sig" s3://downloads-dlang-org/other/ --acl public-read --cache-control max-age=604800
