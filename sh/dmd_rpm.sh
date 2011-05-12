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


# check distribution name
DNAME=""
fdist(){
    if test `cat /etc/*-release | grep -i "$1" | wc -l` -gt 0 ;then
	DNAME="$1"
    fi
}
fdist fedora
fdist openSUSE
if test -z "$DNAME" ;then
    ferror "Only \"fedora\" and \"openSUSE\" suported at this time" "Exiting..."
fi


# show help
if test -z $1 ;then
	echo "Script to create dmd binary rpm packages."
	echo
	echo "Usage:"
	echo "  dmd_rpm.sh -v\"version\""
	echo
	echo "Options:"
	echo "  -v       dmd version (mandatory)"
	exit 1
fi


# too many parameters
if test $# -gt 1 ;then
	ferror "Too many arguments" "Exiting..."
fi


# check version parameter
if test "${1:0:2}" != "-v" ;then
	ferror "Unknown argument" "Exiting..."
elif test "${1:0:4}" != "-v1." -a "${1:0:4}" != "-v2." -o `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "Incorrect version number" "Exiting..."
elif test "${1:0:4}" = "-v1." -a "${1:4}" -lt "68" ;then
	ferror "For \"dmd v1.068\" and newer" "Exiting..."
elif test "${1:0:4}" = "-v2." -a "${1:4}" -lt "53" ;then
	ferror "For \"dmd v2.053\" or newer" "Exiting..."
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
fcheck rpmbuild
fcheck fakeroot
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
    FARCH="x86-32"
elif test `uname -m | grep -iE "x86_64" | wc -l` -eq 1 ;then
    ARCH="x86_64"
    FARCH="x86-64"
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
DMDDIR="dmd-"$VERSION"-"$RELEASE"."$ARCH
RPMFILE="dmd-"$VERSION"-"$RELEASE"."$DNAME"."$ARCH".rpm"


# check if destination rpm file already exist
if test -f $DESTDIR"/"$RPMFILE ;then
	ferror "\"$DESTDIR/$RPMFILE\" already exist" "Exiting..."
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
	cp $DESTDIR"/"d-completion.sh $BASEDIR"/"$DMDDIR"/etc/bash_completion.d/"
fi


# change unzipped folders and files permissions
chmod -R 0755 $BASEDIR/$UNZIPDIR/*
chmod 0644 $(find $BASEDIR/$UNZIPDIR ! -type d)


# switch to temp dir
pushd $BASEDIR"/"$DMDDIR


# install binaries
mkdir -p usr/bin
if test "$ARCH" = "x86_64" ;then
	cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd} usr/bin
else
	cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd} usr/bin
fi


# install libraries
mkdir -p usr/lib
if [ "$UNZIPDIR" = "dmd2" ]; then
	cp -f ../$UNZIPDIR/linux/lib32/libphobos2.a usr/lib
	if test "$ARCH" = "x86_64" ;then
		mkdir -p usr/lib64
		cp -f ../$UNZIPDIR/linux/lib64/libphobos2.a usr/lib64
	fi
else
	cp -f ../$UNZIPDIR/linux/lib32/libphobos.a usr/lib
	if test "$ARCH" = "x86_64" ;then
		mkdir -p usr/lib64
		cp -f ../$UNZIPDIR/linux/lib64/libphobos.a usr/lib64
	fi
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


# rpmize copyright file
mkdir -p usr/share/doc/dmd
echo 'This package was rpmized by '$MAINTAINER'
on '`date -R`'

It was downloaded from http://www.digitalmars.com/d/

' > usr/share/doc/dmd/copyright
cat ../$UNZIPDIR/license.txt >> usr/share/doc/dmd/copyright


# link changelog
ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


# change folders and files permissions
chmod -R 0755 *
chmod 0644 $(find . ! -type d)
chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd}


# find deb package dependencies
if test "$DNAME" = "fedora" ;then
	DEPEND="glibc-devel($FARCH), gcc($FARCH), glibc-devel(x86-32), libgcc(x86-32)"
elif test "$DNAME" = "openSUSE" ;then
	if test "$ARCH" = "x86_64" ; then
		DEPEND="glibc-devel($FARCH), gcc($FARCH), glibc-devel-32bit(x86-32), gcc-32bit($FARCH)"
	else
		DEPEND="glibc-devel($FARCH), gcc($FARCH)"
	fi
fi


# create dmd.spec file
cd ..
echo -e 'Name: dmd
Version: '$VERSION'
Release: '$RELEASE'
Summary: Digital Mars D Compiler

Group: Development/Languages
License: see /usr/share/doc/dmd/copyright
URL: http://www.digitalmars.com/d/
Packager: Jordi Sayol <g.sayol@yahoo.es>

ExclusiveArch: '$ARCH'
Requires: '$DEPEND'
Provides: dmd = '$VERSION'-'$RELEASE', dmd('$FARCH') = '$VERSION'-'$RELEASE'

%description
D is a systems programming language. Its focus is on combining the power and
high performance of C and C++ with the programmer productivity of modern
languages like Ruby and Python. Special attention is given to the needs of
quality assurance, documentation, management, portability and reliability.

The D language is statically typed and compiles directly to machine code.
It\0047s multiparadigm, supporting many programming styles: imperative,
object oriented, and metaprogramming. It\0047s a member of the C syntax
family, and its appearance is very similar to that of C++.

It is not governed by a corporate agenda or any overarching theory of
programming. The needs and contributions of the D programming community form
the direction it goes.

Main designer: Walter Bright

Homepage: http://www.digitalmars.com/d/

%post

F=\0047/etc/dmd.conf\0047

if [ ! -f $F ]; then' > dmd.spec
if [ "$UNZIPDIR" = "dmd2" ]; then
	if [ "$ARCH" = "x86_64" ]; then
		echo '	echo -e "\n[Environment]\n\nDFLAGS= -I/usr/include/d/dmd/phobos -I/usr/include/d/dmd/druntime/import -L-L/usr/lib64 -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic -L-lrt" > $F' >> dmd.spec
	else
		echo '	echo -e "\n[Environment]\n\nDFLAGS= -I/usr/include/d/dmd/phobos -I/usr/include/d/dmd/druntime/import -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic -L-lrt" > $F' >> dmd.spec
	fi
else
	if [ "$ARCH" = "x86_64" ]; then
		echo '	echo -e "\n[Environment]\n\nDFLAGS= -I/usr/include/d/dmd/phobos -L-L/usr/lib64 -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic" > $F' >> dmd.spec
	else
		echo '	echo -e "\n[Environment]\n\nDFLAGS= -I/usr/include/d/dmd/phobos -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic" > $F' >> dmd.spec
	fi
fi
echo -e 'else
	sed -i \0047s/-L-L\/usr\/lib\>//\0047 $F' >> dmd.spec
if [ "$ARCH" = "x86_64" ]; then
	echo -e '	sed -i \0047s/-L-L\/usr\/lib64\>//\0047 $F' >> dmd.spec
fi
echo -e '	sed -i \0047s/-I\/usr\/include\/d\/dmd\/phobos\>//\0047 $F
	sed -i \0047s/-L--no-warn-search-mismatch\>//\0047 $F
	sed -i \0047s/-L--export-dynamic\>//\0047 $F' >> dmd.spec
if [ "$UNZIPDIR" = "dmd2" ]; then
echo -e '	sed -i \0047s/-I\/usr\/include\/d\/dmd\/druntime\/import\>//\0047 $F
	sed -i \0047s/-L-lrt\>//\0047 $F' >> dmd.spec
fi
echo -e '

	L=`sed -n \0047/DFLAGS=/=\0047 $F`

	sed -i $L\0047s/$/ -I\/usr\/include\/d\/dmd\/phobos/\0047 $F
' >> dmd.spec
if [ "$UNZIPDIR" = "dmd2" ]; then
	echo -e '	sed -i $L\0047s/$/ -I\/usr\/include\/d\/dmd\/druntime\/import/\0047 $F
' >> dmd.spec
fi
if [ "$ARCH" = "x86_64" ]; then
	echo -e '	sed -i $L\0047s/$/ -L-L\/usr\/lib64/\0047 $F
' >> dmd.spec
fi
echo -e '	sed -i $L\0047s/$/ -L-L\/usr\/lib/\0047 $F

	sed -i $L\0047s/$/ -L--no-warn-search-mismatch/\0047 $F

	sed -i $L\0047s/$/ -L--export-dynamic/\0047 $F
' >> dmd.spec
if [ "$UNZIPDIR" = "dmd2" ]; then
echo -e '	sed -i $L\0047s/$/ -L-lrt/\0047 $F
' >> dmd.spec
fi
echo -e '	sed -i \0047s/ \+/ /g\0047 $F

fi

%postun

if [ "$1" = "1" ]; then
	exit
fi

rm -f /etc/dmd.conf

%files' >> dmd.spec
find $BASEDIR/$DMDDIR/ -type d | sed 's:'$BASEDIR'/'$DMDDIR':%dir ":' | sed 's:$:":' >> dmd.spec
find $BASEDIR/$DMDDIR/ -type f | sed 's:'$BASEDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec
find $BASEDIR/$DMDDIR/ -type l | sed 's:'$BASEDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec


# create rpm file
fakeroot rpmbuild -vv --buildroot=$BASEDIR/$DMDDIR -bb --target $ARCH dmd.spec | tee rpmbuild.log
TMPRPMFILE=`cat "rpmbuild.log" | grep "dmd-"$VERSION"-"$RELEASE"."$ARCH".rpm" | awk '{print $(NF)}'`


# disable pushd
popd


# place rpm package
mv $TMPRPMFILE $DESTDIR/$RPMFILE


# delete temp dir
rm -Rf $BASEDIR
