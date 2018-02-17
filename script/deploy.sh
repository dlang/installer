#!/usr/bin/env bash

set -uexo pipefail

ROOT=$(dirname $0)

${GPG:-gpg2} --detach-sign install.sh
scp "$ROOT/install.sh" "$ROOT/install.sh.sig" digitalmars.com:/usr/local/www/dlang.org/data/
scp "$ROOT/install.sh" "$ROOT/install.sh.sig" nightlies.dlang.org:/var/www/builds/
aws --profile ddo s3 cp "$ROOT/install.sh" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
aws --profile ddo s3 cp "$ROOT/install.sh.sig" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
