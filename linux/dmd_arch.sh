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
	echo "Script to create dmd v2 binary packages for Arch Linux."
	echo
	echo "Usage:"
	echo "  dmd_arch.sh -v\"version\" -m\"model\" [-f]"
	echo
	echo "Options:"
	echo "  -v       dmd version (mandatory)"
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
elif test "${1:0:4}" != "-v2." -o `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "dmd2: Incorrect version number" "Exiting..."
elif test "${1:0:4}" = "-v2." -a "${1:4}" -lt "62" ;then
	ferror "For \"dmd v2.062\" and newer only" "Exiting..."
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
fcheck wget
fcheck tar
fcheck fakeroot
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


# assign variables
MAINTAINER="Jordi Sayol <g.sayol@yahoo.es>"
VERSION=${1:2}
if [ "$RELEASE" == "" ]
then
	RELEASE=0
fi
DESTDIR=`pwd`
TEMPDIR='/tmp/'`date +"%s%N"`
UNZIPDIR="dmd2"
DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
if test "$2" = "-m64" ;then
	ARCH="x86_64"
elif test "$2" = "-m32" ;then
	ARCH="i386"
fi
ZIPFILE=`basename $DMDURL`
ARCHFILE="dmd-"$VERSION"-"$RELEASE"-"$ARCH".pkg.tar.xz"


# check if destination arch file already exist
if `tar -Jtf $DESTDIR"/"$ARCHFILE &>/dev/null` && test "$3" != "-f" ;then
	echo -e "$ARCHFILE - already exist"
else
	# remove bad formated arch file
	rm -f $DESTDIR"/"$ARCHFILE


	# download zip file if not exist
	if test ! -f $DESTDIR"/"$ZIPFILE ;then
		echo "Downloading $ZIPFILE..."
		wget -nv -P $DESTDIR $DMDURL
	fi


	# create temp dir
	mkdir -p $TEMPDIR/root


	# unpacking sources
	unzip -q $DESTDIR"/"$ZIPFILE -d $TEMPDIR


	# add dmd-completion if present
	if test -f `dirname $0`"/"dmd-completion ;then
		mkdir -p $TEMPDIR"/root/etc/bash_completion.d/"
		cp `dirname $0`"/"dmd-completion $TEMPDIR"/root/etc/bash_completion.d/dmd"
	fi


	# change unzipped folders and files permissions
	chmod -R 0755 $TEMPDIR/$UNZIPDIR/*
	chmod 0644 $(find -L $TEMPDIR/$UNZIPDIR ! -type d)


	# switch to temp dir
	pushd $TEMPDIR/root


	# install binaries
	mkdir -p usr/bin
	if test "$ARCH" = "x86_64" ;then
		cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman} usr/bin
	elif test "$ARCH" = "i386" ;then
		cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman} usr/bin
	fi


	# install libraries
	mkdir -p usr/lib
	PHNAME="libphobos2.a"
	if test "$ARCH" = "x86_64" ;then
		cp -f ../$UNZIPDIR/linux/lib64/$PHNAME usr/lib
	else
		cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib
	fi


	# install include
	find ../$UNZIPDIR/src/ -iname "*.mak" -print0 | xargs -0 rm
	mkdir -p usr/include/dmd/druntime/
	cp -Rf ../$UNZIPDIR/src/phobos/ usr/include/dmd
	cp -Rf ../$UNZIPDIR/src/druntime/import/ usr/include/dmd/druntime


	# install samples and HTML
	mkdir -p usr/share/dmd/
	cp -Rf ../$UNZIPDIR/samples/ usr/share/dmd
	cp -Rf ../$UNZIPDIR/html/ usr/share/dmd
	# remove unneeded files
	find usr/share/dmd/html -regex ".*\.\(d\|c\|h\|lib\|obj\)" -print0 | xargs -0 rm -f


	# install man pages
	gzip ../$UNZIPDIR/man/man1/{dmd.1,dmd.conf.5,dumpobj.1,obj2asm.1,rdmd.1}
	chmod 0644 ../$UNZIPDIR/man/man1/{dmd.1.gz,dmd.conf.5.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz}
	mkdir -p usr/share/man/man1/
	cp -f ../$UNZIPDIR/man/man1/{dmd.1.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz} usr/share/man/man1
	mkdir -p usr/share/man/man5/
	cp -f ../$UNZIPDIR/man/man1/dmd.conf.5.gz usr/share/man/man5


	# copy copyright file
	mkdir -p usr/share/doc/dmd
	cat ../$UNZIPDIR/license.txt | sed 's/\r//' > usr/share/doc/dmd/copyright


	# link changelog
	ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


	# create .PKGINFO file
	echo -e 'pkgname = dmd
	pkgver = '$VERSION-$RELEASE'
	pkgdesc = Digital Mars D Compiler
	url = http://dlang.org/
	builddate = '$(date +%s)'
	packager = '$MAINTAINER'
	size = '$(du -bs . | awk '{print $1}')'
	license = custom
	depend = gcc
	depend = xdg-utils' | sed 's/^\t//' >.PKGINFO
	if test "$ARCH" = "x86_64" ;then
		echo "arch = x86_64" >>.PKGINFO
	else
		echo "arch = i386" >>.PKGINFO
		echo "arch = i486" >>.PKGINFO
		echo "arch = i586" >>.PKGINFO
		echo "arch = i686" >>.PKGINFO
	fi


	# create dmd.conf
	mkdir -p etc
	echo -en ';
	; dmd.conf file for dmd
	;
	; dmd will look for dmd.conf in the following sequence of directories:
	;   - current working directory
	;   - directory specified by the HOME environment variable
	;   - directory dmd resides in
	;   - /etc directory
	;
	; Names enclosed by %% are searched for in the existing environment and inserted
	;
	; The special name %@P% is replaced with the path to this file
	;
	
	[Environment]
	
	DFLAGS=-I/usr/include/dmd/phobos -I/usr/include/dmd/druntime/import' | sed 's/^\t//' > etc/dmd.conf
	echo ' -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic' >> etc/dmd.conf


	# change folders and files permissions
	chmod -R 0755 *
	chmod 0644 $(find -L . ! -type d)
	chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman}


	# create package
	fakeroot tar -Jcf ../$ARCHFILE * .PKGINFO


	# disable pushd
	popd


	# copy package
	cp $TEMPDIR/$ARCHFILE $DESTDIR


	# delete temp dir
	rm -Rf $TEMPDIR
fi

