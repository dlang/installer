#!/bin/bash


set -e -o pipefail


# set variables
KEYID="dmd-apt"
VERSION=${1:2}
RELEASE=0
DESTDIR=`pwd`
APTDIR="apt"
DEB32="dmd_"$VERSION"-"$RELEASE"_i386.deb"
DEB64="dmd_"$VERSION"-"$RELEASE"_amd64.deb"


# error function
ferror(){
	echo -n "error: " >&2
	echo $1 >&2
	exit 1
}


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "refusing to build on a non-debian like system"
fi


# show help
if test -z $1 ;then
	echo "Script to create files needed to build a minimalist dmd apt server."
	echo
	echo "Usage:"
	echo "  build_apt.sh -v\"version\""
	echo
	echo "Options:"
	echo "  -v       dmd version (mandatory)"
	exit
fi


# check if too many parameters
if test $# -gt 1 ;then
	ferror "too many arguments"
fi


# check version parameter
if test "${1:0:2}" != "-v" ;then
	ferror "unknown argument (-v)"
elif ! [[ $1 =~ ^"-v"[0-9]"."[0-9][0-9][0-9]$ ]] ;then
	ferror "incorrect version number"
elif test ${1:2:1}${1:4} -lt 2058 ;then
	ferror "dmd v2.058 and newer only"
fi


# needed commands function
E=0
fcheck(){
	if ! `which $1 1>/dev/null 2>&1` ;then
		LIST=$LIST" "$1
		E=1
	fi
}
fcheck gpg
fcheck md5sum
fcheck sha1sum
fcheck sha256sum
fcheck dpkg-deb
if [ $E -eq 1 ]; then
    ferror "missing commands: $LIST"
fi


# test public key
gpg --no-use-agent -k =$KEYID >/dev/null


# check if deb packages exist
if test ! -f $DESTDIR/$DEB32 -o ! -f $DESTDIR/$DEB64 ;then
	ferror "missing Debian packages for dmd v$VERSION"
fi


# reset and enter apt dir
rm -rf $APTDIR
mkdir -p $APTDIR
cd $APTDIR


# export public key
gpg --no-use-agent --export -a =$KEYID >$KEYID.key


# create links to deb packages
ln -s ../$DEB32 $DEB32
ln -s ../$DEB64 $DEB64


# create "Packages" file
for I in $DEB32 $DEB64
do
	F=`dpkg-deb -f $I | grep -v -e "^ " -e "^Description:" | awk -F : '{print $1}'`
	dpkg-deb -f $I $F >>Packages
	echo "Filename: "`basename $I` >>Packages
	echo "Size: "`du -b -D $I | awk '{print $1}'`  >>Packages
	echo "SHA256: "`sha256sum $I | awk '{print $1}'` >>Packages
	echo "SHA1: "`sha1sum $I | awk '{print $1}'` >>Packages
	echo "MD5sum: "`md5sum $I | awk '{print $1}'` >>Packages
	echo -n "Description: " >>Packages
	dpkg-deb -f $I Description >>Packages
	echo >>Packages
done


# create "Packages.gz" file
gzip -c Packages >Packages.gz


# create "Release" file
echo "Architectures: i386 amd64" >Release
echo "MD5Sum:" >>Release
md5sum Packages | sed "s/^/ /;s/  / $(du -b Packages)/;s/\tPackages/ /" >>Release
md5sum Packages.gz | sed "s/^/ /;s/  / $(du -b Packages.gz)/;s/\tPackages.gz/ /" >>Release
echo "SHA1:" >>Release
sha1sum Packages | sed "s/^/ /;s/  / $(du -b Packages)/;s/\tPackages/ /" >>Release
sha1sum Packages.gz | sed "s/^/ /;s/  / $(du -b Packages.gz)/;s/\tPackages.gz/ /" >>Release
echo "SHA256:" >>Release
sha256sum Packages | sed "s/^/ /;s/  / $(du -b Packages)/;s/\tPackages/ /" >>Release
sha256sum Packages.gz | sed "s/^/ /;s/  / $(du -b Packages.gz)/;s/\tPackages.gz/ /" >>Release


# create "Release.gpg" file
gpg --no-use-agent --output Release.gpg -ba -u =$KEYID Release


# if everything went well
echo -e "APT Repository built"

