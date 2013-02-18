#!/bin/bash


set -e


# set variables
BASEDIR=`dirname $0`
LOGFILE="build_all.log"
SPACER=$(seq -s "*" 71 | sed 's/[0-9]//g')


# error function
ferror()
{
	echo -e "\033[31;1m$SPACER" | sed 's/*/=/g' >&2
	for I in "$@"
	do
		echo -e "$I" >&2
	done
	echo -e "$SPACER\033[0m" | sed 's/*/=/g' >&2
	exit 1
}


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "refusing to build on a non-debian like system" "Exiting..."
fi


# show help
if test $# -eq 0 ;then
	echo "Script to build all deb/rpm/exe packages"
	echo
	echo "Usage:"
	echo "  build_all.sh -v\"version\" [-f]" 
	echo
	echo "Options:"
	echo "  -v\"version\"    dmd version (mandatory)"
	echo "  -f             force to rebuild"
	exit
fi


# check number of parameters
if test $# -gt 2 ;then
	ferror "too many arguments" "Exiting..."
fi


# check version parameter
if test "${1:0:2}" != "-v"
then
	ferror "unknown first argument '$1'" "Exiting..."
elif ! [[ $1 =~ ^"-v"[0-9]"."[0-9][0-9][0-9]$ ]]
then
	ferror "incorrect version number"
elif test ${1:2:1}${1:4} -lt 2062 -o ${1:2:1} -gt 2
then
	ferror "dmd v2.062 and newer only"
fi


# check forced build parameter
if test $# -eq 2 -a "$2" != "-f" ;then
	ferror "unknown second argument '$2'" "Exiting..."
fi


# check needed packages
unset LIST
fcheck()
{
	T="install ok installed"
	if dpkg -s $1 2>/dev/null | grep "$T" &>/dev/null
	then
		echo "Found package $1..."
	else
		echo -e "\033[31;1m* Missing $1...\033[0m"
		LIST=$LIST"\n"$1
	fi
}

fcheck dpkg
fcheck dpkg-dev
fcheck fakeroot
fcheck gnupg
fcheck gzip
fcheck nsis
fcheck coreutils
fcheck rpm
fcheck tar
fcheck unzip
fcheck wget

if [ -n "$LIST" ]
then
	ferror "Mandatory to install these packages first:$LIST"
fi


# remove previous log file
rm -f $LOGFILE


# prints, write logs and run commands
fcmd()
{
	echo -e "\n$SPACER\n$1\n$SPACER" | tee -a $LOGFILE
	$1 2> >(tee -a $LOGFILE >&2)
}


# build dmd2 deb 32-bit
fcmd "$BASEDIR/dmd_deb.sh $1 -m32 $2"


# build dmd2 deb 64-bit
fcmd "$BASEDIR/dmd_deb.sh $1 -m64 $2"


# build dmd2 rpm 32-bit
fcmd "$BASEDIR/dmd_rpm.sh $1 -m32 $2"


# build dmd2 rpm 64-bit
fcmd "$BASEDIR/dmd_rpm.sh $1 -m64 $2"


# build dmd2 arch 32-bit
fcmd "$BASEDIR/dmd_arch.sh $1 -m32 $2"


# build dmd2 arch 64-bit
fcmd "$BASEDIR/dmd_arch.sh $1 -m64 $2"


# build dmd2 windows 32-bit
fcmd "$BASEDIR/dmd_win.sh $1 $2"


# build apt folder/files
fcmd "$BASEDIR/dmd_apt.sh $1"


# if everything went well
echo -e "\n\033[32;40;7;1m Everything properly built! \033[0m"


# remove log file
rm -f $LOGFILE

