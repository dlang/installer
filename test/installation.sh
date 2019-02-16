#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
    echo "Usage: $0 [version (e.g. 2.079.1)]" 1>&2
    exit 1
fi
VERSION="$1"
: ${DOCKER:=docker}

: ${BUILD_DIR:='../create_dmd_release/build'}
# dmd_2.079.1-0_amd64.deb, dmd_2.079.1~beta.1-0_amd64.deb
DEB="dmd_${VERSION/-/\~}-0_amd64.deb"
# dmd-2.079.1-0.fedora.x86_64.rpm, dmd-2.079.1~beta.1-0.fedora.x86_64.rpm
RPM="dmd-${VERSION/-/\~}-0.fedora.x86_64.rpm"
# dmd-2.079.1-0.openSUSE.x86_64.rpm, dmd-2.079.1~beta.1-0.openSUSE.x86_64.rpm
SUSE_RPM="dmd-${VERSION/-/\~}-0.openSUSE.x86_64.rpm"

DEB_PLATFORMS=(ubuntu:precise ubuntu:trusty ubuntu:xenial ubuntu:bionic)
DEB_PLATFORMS+=(debian:wheezy debian:jessie debian:stretch)
RPM_PLATFORMS=(fedora:26 fedora:27 fedora:28 centos:6 centos:7)
SUSE_RPM_PLATFORMS=(opensuse:leap opensuse:tumbleweed)

# copy pkgs to test folder so that it's part of docker's build context
cp "$BUILD_DIR/$DEB" .
cp "$BUILD_DIR/$RPM" .
cp "$BUILD_DIR/$SUSE_RPM" .

trap 'echo -e "\e[1;31mOuter script failed at line $LINENO.\e[0m"' ERR

# platform, package (test script on stdin)
test_platform() {
    local platform="$1"
    local pkg="$2"

    echo -e "\e[1;33mTesting installation of $pkg on $platform.\e[0m"
    img_tag="test_${platform//:/_}"
    # build docker image containing package
    cat > Dockerfile <<EOF
FROM $platform
COPY test_curl.d .
COPY $pkg .
EOF
    "$DOCKER" build --tag="$img_tag" . >/dev/null

    # test installation, using script from caller's stdin
    "$DOCKER" run --rm -i "$img_tag" bash -s

    # remove docker image
    "$DOCKER" rmi "$img_tag" >/dev/null
    rm Dockerfile
}

# ==============================================================================
# DEB
# ------------------------------------------------------------------------------

for platform in "${DEB_PLATFORMS[@]}"; do
    test_platform "$platform" "$DEB" <<EOF
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
done

# ==============================================================================
# RPM
# ------------------------------------------------------------------------------

for platform in "${RPM_PLATFORMS[@]}"; do
    test_platform "$platform" "$RPM" <<EOF
set -euo pipefail

trap 'echo -e "\e[1;31mInner script failed at line \$LINENO.\e[0m"' ERR
set -x

yum install curl --quiet --assumeyes
yum localinstall $RPM --quiet --assumeyes
curl --version >/dev/null
# run a complex D hello world (using libcurl)
dmd -run test_curl.d
EOF
done

# ==============================================================================
# SUSE
# ------------------------------------------------------------------------------

for platform in "${SUSE_RPM_PLATFORMS[@]}"; do
    test_platform "$platform" "$SUSE_RPM" <<EOF
set -euo pipefail

trap 'echo -e "\e[1;31mInner script failed at line \$LINENO.\e[0m"' ERR
set -x

zypper --quiet --non-interactive removerepo 'NON OSS'
zypper --quiet --non-interactive install curl >/dev/null
zypper --quiet --non-interactive --no-gpg-checks install $SUSE_RPM >/dev/null
curl --version >/dev/null
# run a complex D hello world (using libcurl)
dmd -run test_curl.d
EOF
done
