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


# test if in 64-bit system
if [ "$(uname -m)" != "x86_64" ]
then
    ferror "should be run on a 'x86_64' system" "Exiting..."
fi


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "refusing to build on a non-debian like system" "Exiting..."
fi


# show help
if test $# -eq 0 ;then
	echo "Script to build all dmd v2 deb/rpm/exe packages at once"
	echo
	echo "Usage:"
	echo "  build_all.sh -v\"version\" [-f] [-r\"release\"] [-h]" 
	echo
	echo "Options:"
	echo "  -v\"version\"      dmd version (mandatory)"
	echo "  -f               force to rebuild"
	echo "  -r\"release\"      release version (default 0)"
	echo "  -h               show this help and exit"
	exit
fi


# check arguments
unset RELEASE FORCE VER

for I in "$@"
do
	case "$I" in
	-h | -H)
		exec "$0"
	esac
done

for I in "$@"
do
	case "$I" in
	-f)
		FORCE="-f"
		;;
	-r*)
		export RELEASE="${I:2}"
		;;
	-v*)
		VER="${I:2}"
		;;
	*)
		ferror "unknown argument '$I'" "try '`basename $0` -h' for more information."
	esac
done


# version is mandatory
if [ -z "$VER" ]
then
	ferror "missing version" "try '`basename $0` -h' for more information."
fi


# check version parameter
#if ! [[ $VER =~ ^[0-9]"."[0-9][0-9][0-9]$ ]]
#then
#	ferror "incorrect version number" "try '`basename $0` -h' for more information."
#elif test ${VER:0:1} -ne 2
#then
#	ferror "for dmd v2 only" "try '`basename $0` -h' for more information."
#elif test ${VER:0:1}${VER:2} -lt 2062
#then
#	ferror "dmd v2.062 and newer only" "try '`basename $0` -h' for more information."
#fi


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
	ferror "mandatory to install these packages first:$LIST"
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
fcmd "$BASEDIR/dmd_deb.sh -v$VER -m32 $FORCE"


# build dmd2 deb 64-bit
fcmd "$BASEDIR/dmd_deb.sh -v$VER -m64 $FORCE"


# build dmd2 rpm 32-bit
fcmd "$BASEDIR/dmd_rpm.sh -v$VER -m32 $FORCE"


# build dmd2 rpm 64-bit
fcmd "$BASEDIR/dmd_rpm.sh -v$VER -m64 $FORCE"


# build dmd2 arch 32-bit
fcmd "$BASEDIR/dmd_arch.sh -v$VER -m32 $FORCE"


# build dmd2 arch 64-bit
fcmd "$BASEDIR/dmd_arch.sh -v$VER -m64 $FORCE"


# build dmd2 windows 32-bit
fcmd "$BASEDIR/dmd_win.sh -v$VER $FORCE"


# build apt folder/files
#fcmd "$BASEDIR/dmd_apt.sh -v$VER"


# if everything went well
echo -e "\n\033[32;40;7;1m Everything properly built! \033[0m"


# remove log file
rm -f $LOGFILE

