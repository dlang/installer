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
	echo "Script to create dmd v2 binary deb packages."
	echo
	echo "Usage:"
	echo "  dmd_deb.sh -v\"version\" -m\"model\" [-f]"
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
DMDDIR="dmd_"$VERSION"-"$REVISION"_"$ARCH
DIR32="i386-linux-gnu"
DIR64="x86_64-linux-gnu"
DEBFILE=$DMDDIR".deb"


# check if destination deb file already exist
if `dpkg -I $DESTDIR"/"$DEBFILE &>/dev/null` && test "$3" != "-f" ;then
	echo -e "$DEBFILE - already exist"
else
	# remove bad formated deb file
	rm -f $DESTDIR"/"$DEBFILE


	# download zip file if not exist
	if ! $(unzip -c $DESTDIR"/"$ZIPFILE &>/dev/null)
	then
		rm -f $DESTDIR"/"$ZIPFILE
		echo "Downloading $ZIPFILE..."
		curl -fo $DESTDIR"/"$ZIPFILE $DMDURL
	fi


	# create temp dir
	mkdir -p $TEMPDIR"/"$DMDDIR


	# unpacking sources
	unzip -q $DESTDIR"/"$ZIPFILE -d $TEMPDIR


	# add dmd-completion if present
	if test -f `dirname $0`"/"dmd-completion ;then
		mkdir -p $TEMPDIR"/"$DMDDIR"/etc/bash_completion.d/"
		cp `dirname $0`"/"dmd-completion $TEMPDIR"/"$DMDDIR"/etc/bash_completion.d/dmd"
	fi


	# change unzipped folders and files permissions
	chmod -R 0755 $TEMPDIR/$UNZIPDIR/*
	chmod 0644 $(find -L $TEMPDIR/$UNZIPDIR ! -type d)


	# switch to temp dir
	pushd $TEMPDIR"/"$DMDDIR


	# install binaries
	mkdir -p usr/bin
	if test "$ARCH" = "amd64" ;then
		cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman} usr/bin
	elif test "$ARCH" = "i386" ;then
		cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman} usr/bin
	fi


	# install libraries
	mkdir -p usr/lib
	A_LIB="libphobos2.a"
	SO_LIB="libphobos2.so"
	SO_VERSION=$MAJOR.$MINOR
	mkdir -p usr/lib/{$DIR32,$DIR64}
	cp -f ../$UNZIPDIR/linux/lib32/$A_LIB usr/lib/$DIR32
	cp -f ../$UNZIPDIR/linux/lib64/$A_LIB usr/lib/$DIR64
	cp -f ../$UNZIPDIR/linux/lib32/$SO_LIB usr/lib/$DIR32/$SO_LIB.$SO_VERSION.$RELEASE
	cp -f ../$UNZIPDIR/linux/lib64/$SO_LIB usr/lib/$DIR64/$SO_LIB.$SO_VERSION.$RELEASE
	ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR32/$SO_LIB.$SO_VERSION
	ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR64/$SO_LIB.$SO_VERSION
	ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR32/$SO_LIB
	ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$DIR64/$SO_LIB


	# install include
	find ../$UNZIPDIR/src/ -iname "*.mak" -print0 -o -iname "*.ddoc" -print0 | xargs -0 rm -f
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


	# debianize copyright file
	mkdir -p usr/share/doc/dmd
	echo "This package was debianized by $MAINTAINER" > usr/share/doc/dmd/copyright
	echo "on Wed, 15 Aug 2013 00:00:00 +0200" >> usr/share/doc/dmd/copyright
	echo  >> usr/share/doc/dmd/copyright
	echo "It was downloaded from http://dlang.org/" >> usr/share/doc/dmd/copyright
	echo  >> usr/share/doc/dmd/copyright
	echo  >> usr/share/doc/dmd/copyright
	cat ../$UNZIPDIR/license.txt | sed 's/\r//' >> usr/share/doc/dmd/copyright


	# link changelog
	ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


	# create shlibs file
	mkdir -p DEBIAN
	echo "libphobos2 "$MAJOR.$MINOR" libphobos2-"$MINOR > DEBIAN/shlibs


	# create /etc/dmd.conf file
	mkdir -p etc/
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
	if [ "$ARCH" = "amd64" ]; then
		echo -n " -L-L/usr/lib/$DIR64 -L-L/usr/lib/$DIR32" >> etc/dmd.conf
	elif [ "$ARCH" = "i386" ]; then
		echo -n " -L-L/usr/lib/$DIR32 -L-L/usr/lib/$DIR64" >> etc/dmd.conf
	fi
	echo " -L--no-warn-search-mismatch -L--export-dynamic" >> etc/dmd.conf


	# create conffiles file
	mkdir -p DEBIAN
	echo "/etc/dmd.conf" > DEBIAN/conffiles
	if test -f etc/bash_completion.d/dmd ;then
		echo "/etc/bash_completion.d/dmd" >> DEBIAN/conffiles
	fi


	# set deb package dependencies
	DEPENDS="libc6, libc6-dev, gcc, gcc-multilib, libgcc1, libstdc++6, xdg-utils, libcurl3"
	SUGGESTS="libcurl4-openssl-dev"


	# create control file
	echo -e 'Package: dmd
	Version: '$VERSION-$REVISION'
	Architecture: '$ARCH'
	Maintainer: '$MAINTAINER'
	Installed-Size: '$(du -ks usr/ | awk '{print $1}')'
	Depends: '$DEPENDS'
	Suggests: '$SUGGESTS'
	Provides: dmd'$MINOR'
	Section: devel
	Priority: optional
	Homepage: http://dlang.org/
	Description: Digital Mars D Compiler
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
	 Main designer: Walter Bright' | sed 's/^\t//' > DEBIAN/control


	# create md5sum file
	find usr/ -type f -print0 | xargs -0 md5sum > DEBIAN/md5sum
	if test -d etc/ ;then
		find etc/ -type f -print0 | xargs -0 md5sum >> DEBIAN/md5sum
	fi


	# create postinst
	echo -e '#!/bin/sh

	ldconfig || :' | sed 's/^\t//' > DEBIAN/postinst


	# create postrm
	echo -e '#!/bin/sh

	ldconfig || :' | sed 's/^\t//' > DEBIAN/postrm


	# change folders and files permissions
	chmod -R 0755 *
	chmod 0644 $(find -L . ! -type d)
	chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dman} DEBIAN/{postinst,postrm}


	# create deb package
	cd ..
	fakeroot dpkg-deb -b $DMDDIR


	# disable pushd
	popd


	# place deb package
	mv $TEMPDIR"/"$DEBFILE $DESTDIR


	# delete temp dir
	rm -Rf $TEMPDIR
fi

