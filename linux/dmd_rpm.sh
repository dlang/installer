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
	echo "Script to create dmd v1 binary rpm packages."
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
elif test "${1:0:4}" != "-v1." -o `expr length $1` -ne 7 || `echo ${1:4} | grep -q [^[:digit:]]` ;then
	ferror "Incorrect version number" "Exiting..."
elif test "${1:0:4}" = "-v1." -a "${1:4}" -lt "76" ;then
	ferror "For \"dmd v2.076\" and newer only" "Exiting..."
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
fcheck rpmbuild
fcheck fakeroot
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


for DNAME in fedora openSUSE
do
	# assign variables
	MAINTAINER="Jordi Sayol <g.sayol@yahoo.es>"
	VERSION=${1:2}
	if [ "$RELEASE" == "" ]
	then
		RELEASE=0
	fi
	DESTDIR=`pwd`
	TEMPDIR='/tmp/'`date +"%s%N"`
	UNZIPDIR="dmd"
	DMDURL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
	if test "$2" = "-m64" ;then
		ARCH="x86_64"
		FARCH="x86-64"
	elif test "$2" = "-m32" ;then
		ARCH="i386"
		FARCH="x86-32"
	fi
	ZIPFILE=`basename $DMDURL`
	DMDDIR="dmd-"$VERSION"-"$RELEASE"."$ARCH
	RPMFILE="dmd-"$VERSION"-"$RELEASE"."$DNAME"."$ARCH".rpm"
	RPMDIR=$TEMPDIR"/rpmbuild"


	# check if destination rpm file already exist
	if `rpm -qip $DESTDIR"/"$RPMFILE &>/dev/null` && test "$3" != "-f" ;then
		echo -e "$RPMFILE - already exist"
	else
		# remove bad formated rpm file
		rm -f $DESTDIR"/"$RPMFILE


		# download zip file if not exist
		if test ! -f $DESTDIR"/"$ZIPFILE ;then
			echo "Downloading $ZIPFILE..."
			wget -nv -P $DESTDIR $DMDURL
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
			cp -f ../$UNZIPDIR/linux/bin64/{dmd,dumpobj,obj2asm,rdmd} usr/bin
		else
			cp -f ../$UNZIPDIR/linux/bin32/{dmd,dumpobj,obj2asm,rdmd} usr/bin
		fi


		# install libraries
		mkdir -p usr/lib
		PHNAME="libphobos.a"
		cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib
		if test "$ARCH" = "x86_64" ;then
			mkdir -p usr/lib64
			cp -f ../$UNZIPDIR/linux/lib64/$PHNAME usr/lib64
		fi


		# install include
		find ../$UNZIPDIR/src/ -iname "*.mak" -print0 | xargs -0 rm
		mkdir -p usr/include/dmd/
		cp -Rf ../$UNZIPDIR/src/phobos/ usr/include/dmd


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
		echo "This package was rpmized by $MAINTAINER" > usr/share/doc/dmd/copyright
		echo "on `date -R`" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo "It was downloaded from http://dlang.org/" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		cat ../$UNZIPDIR/license.txt | sed 's/\r//' >> usr/share/doc/dmd/copyright


		# link changelog
		ln -s ../../dmd/html/d/changelog.html usr/share/doc/dmd/


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
		
		DFLAGS=-I/usr/include/dmd/phobos' | sed 's/^\t\t//' > etc/dmd.conf
		if [ "$ARCH" = "x86_64" ]; then
			echo -n ' -L-L/usr/lib64' >> etc/dmd.conf
		fi
		echo ' -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic' >> etc/dmd.conf


		# change folders and files permissions
		chmod -R 0755 *
		chmod 0644 $(find . ! -type d)
		chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd}


		# find deb package dependencies
		DEPEND="glibc-devel($FARCH), gcc($FARCH)"
		if test "$ARCH" = "x86_64" ; then
			if test "$DNAME" = "fedora" ;then
				DEPEND=$DEPEND", glibc-devel(x86-32), libgcc(x86-32)"
			elif test "$DNAME" = "openSUSE" ;then
				DEPEND=$DEPEND", glibc-devel-32bit(x86-32), gcc-32bit($FARCH)"
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
		URL: http://dlang.org/
		Packager: Jordi Sayol <g.sayol@yahoo.es>
		
		ExclusiveArch: '$ARCH'
		Requires: '$DEPEND'
		Provides: dmd = '$VERSION-$RELEASE', dmd('$FARCH') = '$VERSION-$RELEASE'
		
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
		
		%files' | sed 's/^\t\t//' > dmd.spec


		# add dir/files to dmd.spec
		find $TEMPDIR/$DMDDIR/ -type d | sed 's:'$TEMPDIR'/'$DMDDIR':%dir ":' | sed 's:$:":' >> dmd.spec
		find $TEMPDIR/$DMDDIR/ -type f | sed 's:'$TEMPDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec
		find $TEMPDIR/$DMDDIR/ -type l | sed 's:'$TEMPDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec


		# mark as %config files
		sed -i 's:^"/etc/dmd.conf"$:%config "/etc/dmd.conf":' dmd.spec
		sed -i 's:^"/etc/bash_completion.d/dmd"$:%config "/etc/bash_completion.d/dmd":' dmd.spec


		# destination directory for the rpm package
		echo >> dmd.spec
		mkdir -p $RPMDIR
		echo "%define _rpmdir $RPMDIR" >> dmd.spec


		# create rpm file
		fakeroot rpmbuild --quiet --buildroot=$TEMPDIR/$DMDDIR -bb --target $ARCH dmd.spec


		# disable pushd
		popd


		# place rpm package
		mv $RPMDIR/$ARCH/dmd-$VERSION-$RELEASE.$ARCH.rpm $DESTDIR"/"$RPMFILE


		# delete temp dir
		rm -Rf $TEMPDIR
	fi
done

