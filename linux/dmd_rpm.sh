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
if test ! -f /etc/debian_version && test ! -f /etc/redhat-release ; then
	ferror "RPMs must be build on a debian or redhat-like system" "Exiting..."
fi


# show help
if test -z $1 ;then
	echo "Script to create dmd v2 binary rpm packages."
	echo
	echo "Usage:"
	echo "  dmd_rpm.sh -v\"version\" -m\"model\" [-f]"
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
	VER_TYPE=0
	[[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]"."[0-9]+$"-beta."[0-9]+$ ]] && VER_TYPE=10
	[[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]"."[0-9]+$"-rc."[0-9]+$ ]] && VER_TYPE=20
	[[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]"."[0-9]+$ ]] && VER_TYPE=100
	if [ $VER_TYPE -eq 0 ]
	then
		ferror "incorrect version number" "Exiting..."
	elif test ${VER:0:1} -ne 2
	then
		ferror "for dmd v2 only" "Exiting..."
	elif test ${VER:0:1}${VER:2:3} -lt 2065
	then
		ferror "dmd v2.065 and newer only" "Exiting..."
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
fcheck rpmbuild
fcheck fakeroot
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


for DNAME in fedora openSUSE
do
	# assign variables
	MAINTAINER="Martin Nowak <code@dawg.eu>"
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
	DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.linux.zip"
	VERSION=$(sed 's/-/~/' <<<$VERSION) # replace dash by tilde
	if test "$2" = "-m64" ;then
		ARCH="x86_64"
		FARCH="x86-64"
	elif test "$2" = "-m32" ;then
		ARCH="i386"
		FARCH="x86-32"
	fi
	ZIPFILE=`basename $DMDURL`
	DMDDIR="dmd-"$VERSION"-"$REVISION"."$ARCH
	RPMFILE="dmd-"$VERSION"-"$REVISION"."$DNAME"."$ARCH".rpm"
	RPMDIR=$TEMPDIR"/rpmbuild"


	# check if destination rpm file already exist
	if [ -f $DESTDIR"/"$RPMFILE ] && `rpm -qip $DESTDIR"/"$RPMFILE &>/dev/null` && test "$3" != "-f" ;then
		echo -e "$RPMFILE - already exist"
	else
		# remove bad formated rpm file
		rm -f $DESTDIR"/"$RPMFILE


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
		chmod 0644 $(find $TEMPDIR/$UNZIPDIR ! -type d)


		# switch to temp dir
		pushd $TEMPDIR"/"$DMDDIR


		# install binaries
		mkdir -p usr/bin
		if test "$ARCH" = "x86_64" ;then
			cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dustmite,dub} usr/bin
		else
			cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dustmite,dub} usr/bin
		fi


		# install libraries
		A_LIB="libphobos2.a"
		SO_LIB="libphobos2.so"
		SO_VERSION=$MAJOR.$MINOR
		mkdir -p usr/lib
		cp -f ../$UNZIPDIR/linux/lib32/$A_LIB usr/lib
		cp -f ../$UNZIPDIR/linux/lib32/$SO_LIB usr/lib/$SO_LIB.$SO_VERSION.$RELEASE
		ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$SO_LIB.$SO_VERSION
		ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib/$SO_LIB
		if test "$ARCH" = "x86_64" ;then
			mkdir -p usr/lib64
			cp -f ../$UNZIPDIR/linux/lib64/$A_LIB usr/lib64
			cp -f ../$UNZIPDIR/linux/lib64/$SO_LIB usr/lib64/$SO_LIB.$SO_VERSION.$RELEASE
			ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib64/$SO_LIB.$SO_VERSION
			ln -s $SO_LIB.$SO_VERSION.$RELEASE usr/lib64/$SO_LIB
		fi


		# install include
		mkdir -p usr/include/dmd/{phobos,druntime}
		cp -Rf ../$UNZIPDIR/src/phobos/{std,etc} usr/include/dmd/phobos/
		cp -Rf ../$UNZIPDIR/src/druntime/import/ usr/include/dmd/druntime/
		# remove unneeded folder
		rm -rf usr/include/dmd/phobos/etc/c/zlib


		# install samples and HTML
		mkdir -p usr/share/dmd/
		cp -Rf ../$UNZIPDIR/samples/ usr/share/dmd
		cp -Rf ../$UNZIPDIR/html/ usr/share/dmd


		# install man pages
		gzip ../$UNZIPDIR/man/man1/{dmd.1,dumpobj.1,obj2asm.1,rdmd.1}
		gzip ../$UNZIPDIR/man/man5/dmd.conf.5
		chmod 0644 ../$UNZIPDIR/man/man1/{dmd.1.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz}
		chmod 0644 ../$UNZIPDIR/man/man5/dmd.conf.5.gz
		mkdir -p usr/share/man/man1/
		cp -f ../$UNZIPDIR/man/man1/{dmd.1.gz,dumpobj.1.gz,obj2asm.1.gz,rdmd.1.gz} usr/share/man/man1
		mkdir -p usr/share/man/man5/
		cp -f ../$UNZIPDIR/man/man5/dmd.conf.5.gz usr/share/man/man5


		# rpmize copyright file
		mkdir -p usr/share/doc/dmd
		echo "This package was rpmized by $MAINTAINER" > usr/share/doc/dmd/copyright
		echo "on Wed, 15 Aug 2013 00:00:00 +0200" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo "It was downloaded from http://dlang.org/" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		cat ../$UNZIPDIR/license.txt | sed 's/\r//' >> usr/share/doc/dmd/copyright


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
		
		[Environment32]
		DFLAGS=-I/usr/include/dmd/phobos -I/usr/include/dmd/druntime/import -L-L/usr/lib -L--export-dynamic
		' | sed 's/^\t\t//' > etc/dmd.conf
		if [ "$ARCH" = "x86_64" ]
		then
			echo -en '
			[Environment64]
			DFLAGS=-I/usr/include/dmd/phobos -I/usr/include/dmd/druntime/import -L-L/usr/lib64 -L--export-dynamic -fPIC
			' | sed 's/^\t\t\t//' >> etc/dmd.conf
		fi


		# change folders and files permissions
		chmod -R 0755 *
		chmod 0644 $(find . ! -type d)
		chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd,ddemangle,dustmite,dub}


		# find deb package dependencies
		if test "$DNAME" = "fedora" ;then
			DEPEND="glibc-devel($FARCH), gcc($FARCH), libcurl($FARCH)"
		elif test "$DNAME" = "openSUSE" ;then
			DEPEND="glibc-devel($FARCH), gcc($FARCH), libcurl4($FARCH)"
		fi
		if test "$ARCH" = "x86_64" ; then
			if test "$DNAME" = "fedora" ;then
				DEPEND=$DEPEND", glibc-devel(x86-32), libgcc(x86-32), libcurl(x86-32)"
			elif test "$DNAME" = "openSUSE" ;then
				DEPEND=$DEPEND", glibc-devel-32bit(x86-32), gcc-32bit($FARCH), libcurl4-32bit(x86-32)"
			fi
		fi


		# create dmd.spec file
		cd ..
		echo -e 'Name: dmd
		Version: '$VERSION'
		Release: '$REVISION'
		Summary: Digital Mars D Compiler

		Group: Development/Languages
		License: see /usr/share/doc/dmd/copyright
		URL: http://dlang.org/
		Packager: '$MAINTAINER'

		ExclusiveArch: '$ARCH'
		Requires: '$DEPEND'
		Provides: dmd = '$VERSION-$REVISION', dmd('$FARCH') = '$VERSION-$REVISION', '$SO_LIB.$SO_VERSION'

		%global __requires_exclude ^libphobos2\\.so.*$

		%description
		D is a systems programming language. Its focus is on combining the power and
		high performance of C and C++ with the programmer productivity of modern
		languages like Ruby and Python. Special attention is given to the needs of
		quality assurance, documentation, management, portability and reliability.

		The D language is statically typed and compiles directly to machine code.
		It\047s multiparadigm, supporting many programming styles: imperative,
		object oriented, functional, and metaprogramming. It\047s a member of the C
		syntax family, and its appearance is very similar to that of C++.

		It is not governed by a corporate agenda or any overarching theory of
		programming. The needs and contributions of the D programming community form
		the direction it goes.

		Main designer: Walter Bright

		%post

		ldconfig || :

		%postun

		ldconfig || :

		%files' | sed 's/^\t\t//' > dmd.spec


		# add dir/files to dmd.spec
		#find $TEMPDIR/$DMDDIR/ -type d | sed 's:'$TEMPDIR'/'$DMDDIR':%dir ":' | sed 's:$:":' >> dmd.spec
		find $TEMPDIR/$DMDDIR/ ! -type d | sed 's:'$TEMPDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec


		# mark as %config files
		sed -i 's:^"/etc/dmd.conf"$:%config "/etc/dmd.conf":' dmd.spec
		sed -i 's:^"/etc/bash_completion.d/dmd"$:%config "/etc/bash_completion.d/dmd":' dmd.spec


		# destination directory for the rpm package
		echo >> dmd.spec
		mkdir -p $RPMDIR
		echo "%define _rpmdir $RPMDIR" >> dmd.spec

		# create rpm file
		fakeroot rpmbuild --quiet --buildroot=$TEMPDIR/$DMDDIR -bb --target $ARCH --define '_binary_payload w9.xzdio' dmd.spec


		# disable pushd
		popd


		# place rpm package
		mv $RPMDIR/$ARCH/dmd-$VERSION-$REVISION.$ARCH.rpm $DESTDIR"/"$RPMFILE


		# delete temp dir
		rm -Rf $TEMPDIR
	fi
done

