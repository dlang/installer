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
	echo "Script to create dmd binary deb packages."
	echo
	echo "Usage:"
	echo "  dmd_deb.sh -v\"version\""
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
elif test "${1:0:4}" != "-v1." -a "${1:0:4}" != "-v2." -o `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "Incorrect version number" "Exiting..."
elif test "${1:0:4}" = "-v1." -a "${1:4}" -lt "68" ;then
	ferror "For \"dmd v1.068\" and newer only" "Exiting..."
elif test "${1:0:4}" = "-v2." -a "${1:4}" -lt "58" ;then
	ferror "For \"dmd v2.058\" and newer only" "Exiting..."
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
fcheck wget
fcheck dpkg-shlibdeps
fcheck fakeroot
fcheck dpkg-deb
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


# assign variables
if test "${1:0:4}" = "-v1." ;then
	UNZIPDIR="dmd"
elif test "${1:0:4}" = "-v2." ;then
	UNZIPDIR="dmd2"
fi
if test `uname -m | grep -iE "i[3-6]86" | wc -l` -eq 1 ;then
    ARCH="i386"
elif test `uname -m | grep -iE "x86_64" | wc -l` -eq 1 ;then
    ARCH="amd64"
else
    ferror "Unknown architecture. \"`uname -m`\"" "Exiting..."
fi
MAINTAINER="Jordi Sayol <g.sayol@yahoo.es>"
VERSION=${1:2}
RELEASE=0
DESTDIR=`dirname $0`
BASEDIR='/tmp/'`date +"%s%N"`
DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
ZIPFILE=`basename $DMDURL`
DMDDIR="dmd_"$VERSION"-"$RELEASE"_"$ARCH
DEBFILE=$DMDDIR".deb"


# check if destination deb file already exist
if test -f $DESTDIR"/"$DEBFILE ;then
	ferror "\"$DESTDIR/$DEBFILE\" already exist" "Exiting..."
fi


# download zip file if not exist
if test ! -f $DESTDIR"/"$ZIPFILE ;then
	wget -P $DESTDIR $DMDURL
fi


# create temp dir
mkdir -p $BASEDIR"/"$DMDDIR


# unpacking sources
unzip $DESTDIR"/"$ZIPFILE -d $BASEDIR


# add d-completion.sh if present
if test -f $DESTDIR"/"d-completion.sh ;then
	mkdir -p $BASEDIR"/"$DMDDIR"/etc/bash_completion.d/"
	cp $DESTDIR"/"d-completion.sh $BASEDIR"/"$DMDDIR"/etc/bash_completion.d/dmd"
fi


# change unzipped folders and files permissions
chmod -R 0755 $BASEDIR/$UNZIPDIR/*
chmod 0644 $(find -L $BASEDIR/$UNZIPDIR ! -type d)


# switch to temp dir
pushd $BASEDIR"/"$DMDDIR


# install binaries
mkdir -p usr/bin
if test "$ARCH" = "amd64" ;then
	cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd} usr/bin
    if [ "$UNZIPDIR" = "dmd2" ]; then
        cp -f ../$UNZIPDIR/linux/bin64/{ddemangle,dman} usr/bin
    fi
elif test "$ARCH" = "i386" ;then
	cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd} usr/bin
    if [ "$UNZIPDIR" = "dmd2" ]; then
        cp -f ../$UNZIPDIR/linux/bin32/{ddemangle,dman} usr/bin
    fi
fi


# install libraries
mkdir -p usr/lib
if [ "$UNZIPDIR" = "dmd2" ]; then
	PHNAME="libphobos2.a"
elif [ "$UNZIPDIR" = "dmd" ]; then
	PHNAME="libphobos.a"
fi
if test "$ARCH" = "amd64" ;then
	mkdir -p usr/lib32
	cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib32
	cp -f ../$UNZIPDIR/linux/lib64/$PHNAME usr/lib
elif test "$ARCH" = "i386" ;then
	mkdir -p usr/lib64
	cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib
	cp -f ../$UNZIPDIR/linux/lib64/$PHNAME usr/lib64
fi


# install include
find ../$UNZIPDIR/src/ -iname "*.mak" -print0 | xargs -0 rm
mkdir -p usr/include/d/dmd/
cp -Rf ../$UNZIPDIR/src/phobos/ usr/include/d/dmd
if [ "$UNZIPDIR" = "dmd2" ]; then
	mkdir -p usr/include/d/dmd/druntime/
	cp -Rf ../$UNZIPDIR/src/druntime/import/ usr/include/d/dmd/druntime
fi


# install samples and HTML
mkdir -p usr/share/dmd/
cp -Rf ../$UNZIPDIR/samples/ usr/share/dmd
cp -Rf ../$UNZIPDIR/html/ usr/share/dmd


# install man pages
gzip ../$UNZIPDIR/man/man1/{dmd.1,dmd.conf.5,dumpobj.1,obj2asm.1,rdmd.1}
chmod 0644 ../$UNZIPDIR/man/man1/{dmd.1.gz,dmd.conf.5.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz}
mkdir -p usr/share/man/man1/
cp -f ../$UNZIPDIR/man/man1/{dmd.1.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz} usr/share/man/man1
mkdir -p usr/share/man/man5/
cp -f ../$UNZIPDIR/man/man1/dmd.conf.5.gz usr/share/man/man5


# debianize copyright file
mkdir -p usr/share/doc/dmd
echo 'This package was debianized by '$MAINTAINER'
on '`date -R`'

It was downloaded from http://d-programming-language.org/

' > usr/share/doc/dmd/copyright
cat ../$UNZIPDIR/license.txt >> usr/share/doc/dmd/copyright


# link changelog
ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


# create /etc/dmd.conf file
mkdir -p etc/
echo '; ' > etc/dmd.conf
echo '; dmd.conf file for dmd' >> etc/dmd.conf
echo '; ' >> etc/dmd.conf
echo '; dmd will look for dmd.conf in the following sequence of directories:' >> etc/dmd.conf
echo ';   - current working directory' >> etc/dmd.conf
echo ';   - directory specified by the HOME environment variable' >> etc/dmd.conf
echo ';   - directory dmd resides in' >> etc/dmd.conf
echo ';   - /etc directory' >> etc/dmd.conf
echo '; ' >> etc/dmd.conf
echo '; Names enclosed by %% are searched for in the existing environment and inserted' >> etc/dmd.conf
echo '; ' >> etc/dmd.conf
echo '; The special name %@P% is replaced with the path to this file' >> etc/dmd.conf
echo '; ' >> etc/dmd.conf
echo >> etc/dmd.conf
echo '[Environment]' >> etc/dmd.conf
echo >> etc/dmd.conf
echo -n 'DFLAGS=-I/usr/include/d -I/usr/include/d/dmd/phobos' >> etc/dmd.conf
if [ "$UNZIPDIR" = "dmd2" ]; then
	echo -n ' -I/usr/include/d/dmd/druntime/import' >> etc/dmd.conf
fi
if [ "$ARCH" = "amd64" ]; then
	echo -n ' -L-L/usr/lib -L-L/usr/lib32' >> etc/dmd.conf
elif [ "$ARCH" = "i386" ]; then
	echo -n ' -L-L/usr/lib -L-L/usr/lib64' >> etc/dmd.conf
fi
echo ' -L--no-warn-search-mismatch -L--export-dynamic' >> etc/dmd.conf


# create conffiles file
mkdir -p DEBIAN
echo "/etc/dmd.conf" > DEBIAN/conffiles
if test -f etc/bash_completion.d/dmd ;then
    echo "/etc/bash_completion.d/dmd" >> DEBIAN/conffiles
fi


# find deb package dependencies
mkdir -p debian/dmd/{DEBIAN,usr/bin/}
echo 'Source: dmd' > debian/control
cp usr/bin/* debian/dmd/usr/bin/
DEPEND=`dpkg-shlibdeps debian/dmd/usr/bin/* -O | sed 's/shlibs:Depends=/libc6-dev, gcc, gcc-multilib, /'`
rm -Rf debian
if test "$UNZIPDIR" = "dmd2" ;then
	DEPEND=$DEPEND", xdg-utils"
fi


# create control file
echo -e 'Package: dmd
Version: '$VERSION'-'$RELEASE'
Architecture: '$ARCH'
Maintainer: '$MAINTAINER'
Installed-Size: '`du -ks usr/| awk '{print $1}'`'
Depends: '$DEPEND'
Section: devel
Priority: optional
Homepage: http://d-programming-language.org/
Description: Digital Mars D Compiler
 D is a systems programming language. Its focus is on combining the power and
 high performance of C and C++ with the programmer productivity of modern
 languages like Ruby and Python. Special attention is given to the needs of
 quality assurance, documentation, management, portability and reliability.
 .
 The D language is statically typed and compiles directly to machine code.
 It\0047s multiparadigm, supporting many programming styles: imperative,
 object oriented, and metaprogramming. It\0047s a member of the C syntax
 family, and its appearance is very similar to that of C++.
 .
 It is not governed by a corporate agenda or any overarching theory of
 programming. The needs and contributions of the D programming community form
 the direction it goes.
 .
 Main designer: Walter Bright
 .
 Homepage: http://d-programming-language.org/
 .' > DEBIAN/control


# create md5sum file
find usr/ -type f -print0 | xargs -0 md5sum > DEBIAN/md5sum
if test -d etc/ ;then
	find etc/ -type f -print0 | xargs -0 md5sum >> DEBIAN/md5sum
fi


# change folders and files permissions
chmod -R 0755 *
chmod 0644 $(find -L . ! -type d)
chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd}
if [ "$UNZIPDIR" = "dmd2" ]; then
    chmod 0755 usr/bin/{ddemangle,dman}
fi


# create deb package
cd ..
fakeroot dpkg-deb -b $DMDDIR


# disable pushd
popd


# place deb package
mv $BASEDIR"/"$DEBFILE $DESTDIR


# delete temp dir
rm -Rf $BASEDIR
