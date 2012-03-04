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
	echo "Script to create dmd binary rpm packages."
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
		FARCH="x86-64"
	elif test "$2" = "-m32" ;then
		ARCH="i386"
		FARCH="x86-32"
	fi
	ZIPFILE=`basename $DMDURL`
	DMDDIR="dmd-"$VERSION"-"$RELEASE"."$ARCH
	RPMFILE="dmd-"$VERSION"-"$RELEASE"."$DNAME"."$ARCH".rpm"
	RPMDIR=$BASEDIR"/rpmbuild"


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
		mkdir -p $BASEDIR"/"$DMDDIR


		# unpacking sources
		unzip -q $DESTDIR"/"$ZIPFILE -d $BASEDIR


		# add dmd-completion if present
		if test -f `dirname $0`"/"dmd-completion ;then
			mkdir -p $BASEDIR"/"$DMDDIR"/etc/bash_completion.d/"
			cp `dirname $0`"/"dmd-completion $BASEDIR"/"$DMDDIR"/etc/bash_completion.d/dmd"
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
			if [ "$UNZIPDIR" = "dmd2" ]; then
				cp -f ../$UNZIPDIR/linux/bin64/{ddemangle,dman} usr/bin
			fi
		else
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
		cp -f ../$UNZIPDIR/linux/lib32/$PHNAME usr/lib
		if test "$ARCH" = "x86_64" ;then
			mkdir -p usr/lib64
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


		# rpmize copyright file
		mkdir -p usr/share/doc/dmd
		echo "This package was rpmized by $MAINTAINER" > usr/share/doc/dmd/copyright
		echo "on `date -R`" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo "It was downloaded from http://dlang.org/" >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
		echo  >> usr/share/doc/dmd/copyright
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
		echo  >> etc/dmd.conf
		echo -n 'DFLAGS=-I/usr/include/d/dmd/phobos' >> etc/dmd.conf
		if [ "$UNZIPDIR" = "dmd2" ]; then
			echo -n ' -I/usr/include/d/dmd/druntime/import' >> etc/dmd.conf
		fi
		if [ "$ARCH" = "x86_64" ]; then
			echo -n ' -L-L/usr/lib64' >> etc/dmd.conf
		fi
		echo ' -L-L/usr/lib -L--no-warn-search-mismatch -L--export-dynamic' >> etc/dmd.conf


		# change folders and files permissions
		chmod -R 0755 *
		chmod 0644 $(find . ! -type d)
		chmod 0755 usr/bin/{dmd,dumpobj,obj2asm,rdmd}
		if [ "$UNZIPDIR" = "dmd2" ]; then
			chmod 0755 usr/bin/{ddemangle,dman}
		fi


		# find deb package dependencies
		DEPEND="glibc-devel($FARCH), gcc($FARCH)"
		if test "$ARCH" = "x86_64" ; then
			if test "$DNAME" = "fedora" ;then
				DEPEND=$DEPEND", glibc-devel(x86-32), libgcc(x86-32)"
			elif test "$DNAME" = "openSUSE" ;then
				DEPEND=$DEPEND", glibc-devel-32bit(x86-32), gcc-32bit($FARCH)"
			fi
		fi

		if test "$UNZIPDIR" = "dmd2" ;then
			DEPEND=$DEPEND", xdg-utils"
		fi


		# create dmd.spec file
		cd ..
		echo "Name: dmd" > dmd.spec
		echo "Version: $VERSION" >> dmd.spec
		echo "Release: $RELEASE" >> dmd.spec
		echo "Summary: Digital Mars D Compiler" >> dmd.spec
		echo >> dmd.spec
		echo "Group: Development/Languages" >> dmd.spec
		echo "License: see /usr/share/doc/dmd/copyright" >> dmd.spec
		echo "URL: http://dlang.org/" >> dmd.spec
		echo "Packager: Jordi Sayol <g.sayol@yahoo.es>" >> dmd.spec
		echo >> dmd.spec
		echo "ExclusiveArch: $ARCH" >> dmd.spec
		echo "Requires: $DEPEND" >> dmd.spec
		echo "Provides: dmd = $VERSION-$RELEASE, dmd($FARCH) = $VERSION-$RELEASE" >> dmd.spec
		echo >> dmd.spec
		echo "%description" >> dmd.spec
		echo "D is a systems programming language. Its focus is on combining the power and" >> dmd.spec
		echo "high performance of C and C++ with the programmer productivity of modern" >> dmd.spec
		echo "languages like Ruby and Python. Special attention is given to the needs of" >> dmd.spec
		echo "quality assurance, documentation, management, portability and reliability." >> dmd.spec
		echo >> dmd.spec
		echo "The D language is statically typed and compiles directly to machine code." >> dmd.spec
		echo "It's multiparadigm, supporting many programming styles: imperative," >> dmd.spec
		echo "object oriented, functional, and metaprogramming. It's a member of the C" >> dmd.spec
		echo "syntax family, and its appearance is very similar to that of C++." >> dmd.spec
		echo >> dmd.spec
		echo "It is not governed by a corporate agenda or any overarching theory of" >> dmd.spec
		echo "programming. The needs and contributions of the D programming community form" >> dmd.spec
		echo "the direction it goes." >> dmd.spec
		echo >> dmd.spec
		echo "Main designer: Walter Bright" >> dmd.spec
		echo >> dmd.spec
		echo "%files" >> dmd.spec


		# add dir/files to dmd.spec
		find $BASEDIR/$DMDDIR/ -type d | sed 's:'$BASEDIR'/'$DMDDIR':%dir ":' | sed 's:$:":' >> dmd.spec
		find $BASEDIR/$DMDDIR/ -type f | sed 's:'$BASEDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec
		find $BASEDIR/$DMDDIR/ -type l | sed 's:'$BASEDIR'/'$DMDDIR':":' | sed 's:$:":' >> dmd.spec


		# mark as %config files
		sed -i 's:^"/etc/dmd.conf"$:%config "/etc/dmd.conf":' dmd.spec
		sed -i 's:^"/etc/bash_completion.d/dmd"$:%config "/etc/bash_completion.d/dmd":' dmd.spec


		# destination directory for the rpm package
		echo >> dmd.spec
		mkdir -p $RPMDIR
		echo "%define _rpmdir $RPMDIR" >> dmd.spec


		# create rpm file
		fakeroot rpmbuild --buildroot=$BASEDIR/$DMDDIR -bb --target $ARCH dmd.spec


		# disable pushd
		popd


		# place rpm package
		mv $RPMDIR/$ARCH/dmd-$VERSION-$RELEASE.$ARCH.rpm $DESTDIR"/"$RPMFILE


		# delete temp dir
		rm -Rf $BASEDIR
	fi
done

