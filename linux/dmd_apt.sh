#!/bin/bash


set -e -o pipefail


# error function
ferror(){
	echo "=========================================================="
	echo $1
	echo $2
	echo "=========================================================="
	exit 1
}


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "Refusing to build on a non-debian like system" "Exiting..."
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
	ferror "Too many arguments" "Exiting..."
fi


# check version parameter
if test "${1:0:2}" != "-v" ;then
	ferror "Unknown argument" "Exiting..."
elif test `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "Incorrect version number" "Exiting..."
elif test "${1:0:4}" != "-v2." -o "${1:4}" -lt "58" ;then
	ferror "For dmd v2.058 and newer only" "Exiting..."
fi


# set variables
SIGNKEY="dmd-apt"
VERSION=${1:2}
RELEASE=0
DESTDIR=`pwd`
DEB32=$DESTDIR"/dmd_"$VERSION"-"$RELEASE"_i386.deb"
DEB64=$DESTDIR"/dmd_"$VERSION"-"$RELEASE"_amd64.deb"
F="Package Source Version Section Priority Architecture"
F="$F Essential Depends Recommends Suggests Enhances"
F="$F Pre-Depends Installed-Size Maintainer Homepage"


# check if two deb packages exist
if test ! -f $DEB32 -o ! -f $DEB64 ;then
	ferror "Missing Debian packages for dmd v$VERSION" "Exiting..."
fi

# remove files
rm -f $DESTDIR/Packages $DESTDIR/Packages.gz $DESTDIR/Release $DESTDIR/Release.gpg


# create "Packages" file
for I in $DEB32 $DEB64
do
	dpkg-deb -f $I $F >>$DESTDIR/Packages
	echo "Filename: "`basename $I` >>$DESTDIR/Packages
	echo "Size: "`du -b -D $I | awk '{print $1}'`  >>$DESTDIR/Packages
	echo "SHA256: "`sha256sum $I | awk '{print $1}'` >>$DESTDIR/Packages
	echo "SHA1: "`sha1sum $I | awk '{print $1}'` >>$DESTDIR/Packages
	echo "MD5sum: "`md5sum $I | awk '{print $1}'` >>$DESTDIR/Packages
	echo -n "Description: " >>$DESTDIR/Packages
	dpkg-deb -f $I Description >>$DESTDIR/Packages
	echo >>$DESTDIR/Packages
done


# create "Packages.gz" file
gzip -c $DESTDIR/Packages >$DESTDIR/Packages.gz


# create "Release" file
echo "Architectures: i386 amd64" >$DESTDIR/Release
echo "MD5Sum:" >>$DESTDIR/Release
md5sum $DESTDIR/Packages | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages)#;s#\t$DESTDIR/Packages$DESTDIR/# #" >>$DESTDIR/Release
md5sum $DESTDIR/Packages.gz | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages.gz)#;s#\t$DESTDIR/Packages.gz$DESTDIR/# #" >>$DESTDIR/Release
echo "SHA1:" >>$DESTDIR/Release
sha1sum $DESTDIR/Packages | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages)#;s#\t$DESTDIR/Packages$DESTDIR/# #" >>$DESTDIR/Release
sha1sum $DESTDIR/Packages.gz | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages.gz)#;s#\t$DESTDIR/Packages.gz$DESTDIR/# #" >>$DESTDIR/Release
echo "SHA256:" >>$DESTDIR/Release
sha256sum $DESTDIR/Packages | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages)#;s#\t$DESTDIR/Packages$DESTDIR/# #" >>$DESTDIR/Release
sha256sum $DESTDIR/Packages.gz | sed "s#^# #;s#  # $(du -b $DESTDIR/Packages.gz)#;s#\t$DESTDIR/Packages.gz$DESTDIR/# #" >>$DESTDIR/Release


# create "Release.gpg" file
gpg --output $DESTDIR/Release.gpg -ba -u $SIGNKEY $DESTDIR/Release

