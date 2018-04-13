#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
    echo "Usage: $0 [version (e.g. 2.079.1)]" 1>&2
    exit 1
fi
VERSION="$1"

: ${BUILD_DIR:='../create_dmd_release/build'}
DEB="dmd_$VERSION-0_amd64.deb"
# TODO: test rpms
#RPM="$BUILD_DIR/dmd-$VERSION-0.fedora.x86_64.rpm"
#SUSE_RPM="$BUILD_DIR/dmd-$VERSION-0.openSUSE.x86_64.rpm"
DEB_PLATFORMS=(ubuntu:precise ubuntu:trusty ubuntu:xenial ubuntu:bionic)
DEB_PLATFORMS+=(debian:wheezy debian:jessie debian:stretch)

# copy pkgs to test folder so that it's part of docker's build context
cp "$BUILD_DIR/dmd_$VERSION-0_amd64.deb" .
# TODO: test rpms
#cp "$BUILD_DIR/dmd-$VERSION-0.fedora.x86_64.rpm" .
#cp "$BUILD_DIR/dmd-$VERSION-0.openSUSE.x86_64.rpm" .

trap 'echo -e "\e[1;31mOuter script failed at line $LINENO.\e[0m"' ERR

for platform in "${DEB_PLATFORMS[@]}"; do
    echo -e "\e[1;33mTesting installation of $DEB on $platform.\e[0m"
    img_tag="test_${platform//:/_}"
    # build docker image containing package
    cat > Dockerfile <<EOF
FROM $platform
COPY test_curl.d .
COPY $DEB .
EOF
    docker build . --tag="$img_tag" >/dev/null

    # test installation
    docker run --rm -i "$img_tag" bash -s <<EOF
set -euo pipefail

trap 'echo -e "\e[1;31mInner script failed at line \$LINENO.\e[0m"' ERR
set -x

apt-get update -q=2 >/dev/null
apt-get install curl -q=2 >/dev/null
dpkg -i $DEB || true
apt-get --fix-broken install -q=2 >/dev/null
# check that both dmd and curl are still installed
dpkg-query -W --showformat='\${Status}\n' dmd | grep -F 'install ok installed'
dpkg-query -W --showformat='\${Status}\n' curl | grep -F 'install ok installed'
curl --version >/dev/null
# run a complex D hello world (using libcurl)
dmd -run test_curl.d
EOF

    # remove docker image
    docker rmi "$img_tag" >/dev/null
    rm Dockerfile
done
