#!/usr/bin/env bash

set -uexo pipefail

ROOT=$(dirname $0)

function rsync_with_perms()
{
    rsync --perms --chmod=u+rw,g+rw,o+r "$@"
}

${GPG:-gpg2} --detach-sign install.sh
rsync_with_perms "$ROOT/install.sh" "$ROOT/install.sh.sig" digitalmars.com:/usr/local/www/dlang.org/data/
rsync_with_perms "$ROOT/install.sh" "$ROOT/install.sh.sig" nightlies.dlang.org:/var/www/builds/
aws --profile ddo s3 cp "$ROOT/install.sh" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
aws --profile ddo s3 cp "$ROOT/install.sh.sig" s3://downloads.dlang.org/other/ --acl public-read --cache-control max-age=604800
