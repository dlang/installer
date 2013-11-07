#!/bin/bash


set -e -o pipefail


# error function
ferror(){
	echo "==========================================================" >&2
	echo $1 >&2
	echo $2 >&2
	echo "==========================================================" >&2
	exit 1
}


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "Refusing to build on a non-debian like system" "Exiting..."
fi


# show help
if test -z $1 ;then
	echo "Script to create phobos library v2 binary deb packages."
	echo
	echo "Usage:"
	echo "  dmd_phobos.sh -v\"version\" -m\"model\" [-f]"
	echo
	echo "Options:"
	echo "  -v       phobos version (mandatory)"
	echo "  -m       32 or 64 (mandatory)"
	echo "  -f       force to rebuild"
	exit
fi


# check if too many parameters
if test $# -gt 3 ;then
	ferror "Too many arguments" "Exiting..."
fi


# check version parameter
if test "${1:0:2}" != "-v" ;then
	ferror "Unknown first argument (-v)" "Exiting..."
else
	VER="${1:2}"
	if ! [[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]$ || $VER =~ ^[0-9]"."[0-9][0-9][0-9]"."[0-9]+$ ]]
	then
		ferror "incorrect version number" "Exiting..."
	elif test ${VER:0:1} -ne 2
	then
		ferror "for dmd v2 only" "Exiting..."
	elif test ${VER:0:1}${VER:2:3} -lt 2063
	then
		ferror "dmd v2.063 and newer only" "Exiting..."
	fi
fi


# check model parameter
if test $# -eq 1 ;then
	ferror "Second argument is mandatory (-m[32-64])" "Exiting..."
elif test "$2" != "-m32" -a "$2" != "-m64" ;then
	ferror "Unknown second argument '$2'" "Exiting..."
fi


# check forced build parameter
if test $# -eq 3 -a "$3" != "-f" ;then
	ferror "Unknown third argument '$3'" "Exiting..."
fi


# needed commands function
E=0
fcheck(){
	if ! `which $1 1>/dev/null 2>&1` ;then
		LIST=$LIST" "$1
		E=1
	fi
}
fcheck gzip
fcheck unzip
fcheck curl
fcheck dpkg
fcheck dpkg-shlibdeps
fcheck fakeroot
fcheck dpkg-deb
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


# assign variables
MAINTAINER="Jordi Sayol <g.sayol@yahoo.es>"
VERSION=${1:2}
MAJOR=0
MINOR=$(awk -F. '{ print $2 +0 }' <<<$VERSION)
RELEASE=$(awk -F. '{ print $3 +0 }' <<<$VERSION)
if [ "$REVISION" == "" ]
then
	REVISION=0
fi
DESTDIR=`pwd`
TEMPDIR='/tmp/'`date +"%s%N"`
UNZIPDIR="dmd2"
DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
if test "$2" = "-m64" ;then
	ARCH="amd64"
elif test "$2" = "-m32" ;then
	ARCH="i386"
fi
ZIPFILE=`basename $DMDURL`
PHOBOSPKG="libphobos2-"$MINOR
PHOBOSDIR=$PHOBOSPKG"_"$VERSION"-"$REVISION"_"$ARCH
DIR32="i386-linux-gnu"
DIR64="x86_64-linux-gnu"
PHOBOSFILE=$PHOBOSDIR".deb"


# check if destination deb file already exist
if `dpkg -I $DESTDIR"/"$PHOBOSFILE &>/dev/null` && test "$3" != "-f" ;then
	echo -e "$PHOBOSFILE - already exist"
else
	# remove bad formated deb file
	rm -f $DESTDIR"/"$PHOBOSFILE


	# download zip file if not exist
	if ! $(unzip -c $DESTDIR"/"$ZIPFILE &>/dev/null)
	then
		rm -f $DESTDIR"/"$ZIPFILE
		echo "Downloading $ZIPFILE..."
		curl -fo $DESTDIR"/"$ZIPFILE $DMDURL
	fi


	# create temp dir
	mkdir -p $TEMPDIR"/"$PHOBOSDIR


	# unpacking sources
	unzip -q $DESTDIR"/"$ZIPFILE -d $TEMPDIR


	# change unzipped folders and files permissions
	chmod -R 0755 $TEMPDIR/$UNZIPDIR/*
	chmod 0644 $(find -L $TEMPDIR/$UNZIPDIR ! -type d)


	# switch to temp dir
	pushd $TEMPDIR"/"$PHOBOSDIR


	# install library
	SO_LIB="libphobos2.so"
	SO_VERSION=$MAJOR.$MINOR
	if [ "$ARCH" == "amd64" ]
	then
		mkdir -p usr/lib/$DIR64
		cp -f ../$UNZIPDIR/linux/lib64/$SO_LIB usr/lib/$DIR64/$SO_LIB.$SO_VERSION.$RELEASE
		ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR64/$SO_LIB.$SO_VERSION
	elif [ "$ARCH" == "i386" ]
	then
		mkdir -p usr/lib/$DIR32
		cp -f ../$UNZIPDIR/linux/lib32/$SO_LIB usr/lib/$DIR32/$SO_LIB.$SO_VERSION.$RELEASE
		ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR32/$SO_LIB.$SO_VERSION
	fi


	# generate copyright file
	mkdir -p usr/share/doc/$PHOBOSPKG
	I="../$UNZIPDIR/src/druntime/LICENSE"
	sed 's/\r//;s/^[ \t]\+$//;s/^$/./;s/^/ /' $I > $I"_tmp"
	if [ $(sed -n '/====/=' $I"_tmp") ]
	then
		sed -i '1,/====/d' $I"_tmp"
	fi
	sed -i ':a;$!{N;ba};s/^\( .\s*\n\)*\|\(\s*\n .\)*$//g' $I"_tmp"
	echo 'Format: http://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
	Source: https://github.com/D-Programming-Language

	Files: usr/lib/*
	Copyright: 1999-'$(date +%Y)' by Digital Mars written by Walter Bright
	License: Boost License 1.0' | sed 's/^\t//' > usr/share/doc/$PHOBOSPKG/copyright
	cat ../$UNZIPDIR/src/druntime/LICENSE_tmp >> usr/share/doc/$PHOBOSPKG/copyright


	# create changelog
	echo "See: https://github.com/D-Programming-Language/phobos/commits/master" > usr/share/doc/$PHOBOSPKG/changelog


	# create shlibs file
	mkdir -p DEBIAN
	echo "libphobos2 "$MAJOR.$MINOR" libphobos2-"$MINOR > DEBIAN/shlibs


	# set deb package dependencies
	DEPENDS="libc6, libcurl3"


	# create control file
	echo -e 'Package: libphobos2-'$MINOR'
	Source: libphobos
	Version: '$VERSION-$REVISION'
	Architecture: '$ARCH'
	Maintainer: '$MAINTAINER'
	Installed-Size: '$(du -ks usr/ | awk '{print $1}')'
	Pre-Depends: multiarch-support
	Depends: '$DEPENDS'
	Conflicts: dmd'$MINOR'
	Replaces: dmd'$MINOR'
	Section: libs
	Priority: optional
	Multi-Arch: same
	Homepage: http://dlang.org/
	Description: Phobos for DMD2 (Runtime library)
	 Phobos is the standard library for the D Programming Language.
	 .
	 D is a systems programming language. Its focus is on combining the power and
	 high performance of C and C++ with the programmer productivity of modern
	 languages like Ruby and Python. Special attention is given to the needs of
	 quality assurance, documentation, management, portability and reliability.
	 .
	 The D language is statically typed and compiles directly to machine code.
	 It\047s multiparadigm, supporting many programming styles: imperative,
	 object oriented, functional, and metaprogramming. It\047s a member of the C
	 syntax family, and its appearance is very similar to that of C++.
	 .
	 It is not governed by a corporate agenda or any overarching theory of
	 programming. The needs and contributions of the D programming community form
	 the direction it goes.
	 .
	 Main designer: Walter Bright
	 .
	 This package contains the shared library needed to run programs compiled with dmd.' | sed 's/^\t//' > DEBIAN/control


	# create md5sum file
	find usr/ -type f -print0 | xargs -0 md5sum > DEBIAN/md5sum


	# create postinst
	echo -e '#!/bin/sh

	ldconfig || :' | sed 's/^\t//' > DEBIAN/postinst


	# create postrm
	echo -e '#!/bin/sh

	ldconfig || :' | sed 's/^\t//' > DEBIAN/postrm


	# change folders and files permissions
	chmod -R 0755 *
	chmod 0644 $(find -L . ! -type d ! -name "$SO_LIB.$SO_VERSION")
	chmod 0755 DEBIAN/{postinst,postrm}


	# create deb package
	cd ..
	fakeroot dpkg-deb -b $PHOBOSDIR


	# disable pushd
	popd


	# place deb package
	mv $TEMPDIR"/"$PHOBOSFILE $DESTDIR


	# delete temp dir
	rm -Rf $TEMPDIR
fi

