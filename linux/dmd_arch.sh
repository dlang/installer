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
	echo "Script to create dmd binary packages for Arch Linux."
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
elif test "${1:0:4}" != "-v1." -a "${1:0:4}" != "-v2." -o `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "Incorrect version number" "Exiting..."
elif test "${1:0:4}" = "-v1." -a "${1:4}" -lt "73" ;then
	ferror "For \"dmd v1.073\" and newer only" "Exiting..."
elif test "${1:0:4}" = "-v2." -a "${1:4}" -lt "58" ;then
	ferror "For \"dmd v2.058\" and newer only" "Exiting..."
fi


# check model parameter
if test $# -eq 1 ;then
	ferror "Second argument is mandatory (-m[32-64])" "Exiting..."
elif test "$2" != "-m32" -a "$2" != "-m64" ;then
	ferror "Unknown second argument (-m[32-64])" "Exiting..."
fi


# check forced build parameter
if test $# -eq 3 -a "$3" != "-f" ;then
	ferror "Unknown third argument (-f)" "Exiting..."
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
RELEASE=0
DESTDIR=`pwd`
BASEDIR='/tmp/'`date +"%s%N"`
if test "${1:0:4}" = "-v1." ;then
	UNZIPDIR="dmd"
	DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
elif test "${1:0:4}" = "-v2." ;then
	UNZIPDIR="dmd2"
	DMDURL="https://github.com/downloads/D-Programming-Language/dmd/dmd.$VERSION.zip"
fi
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
	mkdir -p $BASEDIR/root


	# unpacking sources
	unzip -q $DESTDIR"/"$ZIPFILE -d $BASEDIR


	# add dmd-completion if present
	if test -f `dirname $0`"/"dmd-completion ;then
		mkdir -p $BASEDIR"/root/etc/bash_completion.d/"
		cp `dirname $0`"/"dmd-completion $BASEDIR"/root/etc/bash_completion.d/dmd"
	fi


	# change unzipped folders and files permissions
	chmod -R 0755 $BASEDIR/$UNZIPDIR/*
	chmod 0644 $(find -L $BASEDIR/$UNZIPDIR ! -type d)


	# switch to temp dir
	pushd $BASEDIR/root


	# install binaries
	mkdir -p usr/bin
	if test "$ARCH" = "x86_64" ;then
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
	if test "$ARCH" = "x86_64" ;then
		cp -f ../$UNZIPDIR/linux/lib64/$PHNAME usr/lib
	else
		cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib
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


	# copy copyright file
	mkdir -p usr/share/doc/dmd
	cp ../$UNZIPDIR/license.txt usr/share/doc/dmd/copyright


	# link changelog
	ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


	# create .PKGINFO file
	echo "pkgname = dmd" >.PKGINFO
	echo "pkgver = $VERSION-$RELEASE" >>.PKGINFO
	echo "pkgdesc = Digital Mars D Compiler" >>.PKGINFO
	echo "url = http://dlang.org/" >>.PKGINFO
	echo "builddate = `date +%s`" >>.PKGINFO
	echo "packager = $MAINTAINER" >>.PKGINFO
	echo "size = `du -bs . | awk '{print $1}'`" >>.PKGINFO
	echo "license = custom" >>.PKGINFO
	echo "depend = gcc" >>.PKGINFO
	if test "$UNZIPDIR" = "dmd2" ;then
		echo "depend = xdg-utils" >>.PKGINFO
	fi
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
	echo "; " > etc/dmd.conf
	echo "; dmd.conf file for dmd" >> etc/dmd.conf
	echo "; " >> etc/dmd.conf
	echo "; dmd will look for dmd.conf in the following sequence of directories:" >> etc/dmd.conf
	echo ";   - current working directory" >> etc/dmd.conf
	echo ";   - directory specified by the HOME environment variable" >> etc/dmd.conf
	echo ";   - directory dmd resides in" >> etc/dmd.conf
	echo ";   - /etc directory" >> etc/dmd.conf
	echo "; " >> etc/dmd.conf
	echo "; Names enclosed by %% are searched for in the existing environment and inserted" >> etc/dmd.conf
	echo "; " >> etc/dmd.conf
	echo "; The special name %@P% is replaced with the path to this file" >> etc/dmd.conf
	echo "; " >> etc/dmd.conf
	echo >> etc/dmd.conf
	echo "[Environment]" >> etc/dmd.conf
	echo >> etc/dmd.conf
	if [ "$UNZIPDIR" = "dmd2" ]; then
		echo "DFLAGS=-I/usr/include/d/dmd/phobos -I/usr/include/d/dmd/druntime/import -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic" >> etc/dmd.conf
	else
		echo "DFLAGS=-I/usr/include/d/dmd/phobos -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic" >> etc/dmd.conf
	fi


	# change folders and files permissions
	chmod -R 0755 *
	chmod 0644 $(find -L . ! -type d)
	chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd}
	if [ "$UNZIPDIR" = "dmd2" ]; then
		chmod 0755 usr/bin/{ddemangle,dman}
	fi


	# create package
	fakeroot tar -Jcf ../$ARCHFILE * .PKGINFO


	# disable pushd
	popd


	# copy package
	cp $BASEDIR/$ARCHFILE $DESTDIR


	# delete temp dir
	rm -Rf $BASEDIR
fi

