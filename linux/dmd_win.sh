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
	echo "Script to create dmd v2 Windows installer"
	echo
	echo "Usage:"
	echo "  dmd_win.sh -v\"version\" [-f]"
	echo
	echo "Options:"
	echo "  -v       dmd version (mandatory)"
	echo "  -f       force to rebuild"
	exit
fi


# check if too many parameters
if test $# -gt 2 ;then
	ferror "Too many arguments" "Exiting..."
fi


# check version parameter
if test "${1:0:2}" != "-v" ;then
	ferror "Unknown first argument (-v)" "Exiting..."
else
	VER="${1:2}"
	if ! [[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]$ || $VER =~ ^[0-9]"."[0-9][0-9][0-9]"."[0-9]$ ]]
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


# check forced build parameter
if test $# -eq 2 -a "$2" != "-f" ;then
	ferror "Unknown second argument '$2'" "Exiting..."
fi


# needed commands function
E=0
fcheck(){
	if ! `which $1 1>/dev/null 2>&1` ;then
		LIST=$LIST" "$1
		E=1
	fi
}
fcheck unzip
fcheck curl
fcheck makensis
if [ $E -eq 1 ]; then
    ferror "Missing commands on Your system:" "$LIST"
fi


# assign variables
VERSION=${1:2}
CURLVERSION="7.24.0"
DESTDIR=`pwd`
TEMPDIR='/tmp/'`date +"%s%N"`
DMD_URL="http://ftp.digitalmars.com/dmd.$VERSION.zip"
DMC_URL="http://ftp.digitalmars.com/dmc.zip"
CURL_URL="http://downloads.dlang.org/other/curl-$CURLVERSION-dmd-win32.zip"
EXEFILE="dmd-$VERSION.exe"
NSI="installer.nsi"


# check if destination exe file already exist
if $(file $DESTDIR/$EXEFILE | grep "MS Windows" &>/dev/null) && [ "$2" != "-f" ]
then
	echo -e "$EXEFILE - already exist"
else
	# remove exe file
	rm -f $DESTDIR/$EXEFILE


	# download zip file if they don't exists
	for F in $DMD_URL $DMC_URL $CURL_URL
	do
		if ! $(unzip -c $DESTDIR"/"$(basename $F) &>/dev/null)
		then
			rm -f $DESTDIR"/"$(basename $F)
			echo "Downloading $(basename $F)..."
			curl -o $DESTDIR"/"$(basename $F) $F
		fi
	done


	# create temp dir
	mkdir -p $TEMPDIR


	# unpacking sources
	unzip -q $DESTDIR/$(basename $DMD_URL) -d $TEMPDIR/dmd
	unzip -q $DESTDIR/$(basename $DMC_URL) -d $TEMPDIR
	unzip -q $DESTDIR/$(basename $CURL_URL) -d $TEMPDIR/curl


	# copy needed files to temp directory
	cp -f $(dirname $0)/win/* $TEMPDIR


	# switch to temp dir
	pushd $TEMPDIR


	# remove unneeded files
	rm -rf dmd/dmd2/{freebsd,linux,man,osx,src/dmd}
	find dmd/dmd2/html -regex ".*\.\(d\|c\|h\|lib\|obj\)" -print0 | xargs -0 rm -f


	# create exe file
	makensis -V3 -DVersion=$VERSION -DExeFile=$EXEFILE $NSI


	# disable pushd
	popd


	# place exe installer
	mv $TEMPDIR/$EXEFILE $DESTDIR


	# delete temp dir
	rm -Rf $TEMPDIR
fi

