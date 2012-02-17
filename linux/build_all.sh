#!/bin/bash


set -e


# set variables
DESTDIR=`dirname $0`
LOGFILE="build_all.log"


# error function
ferror(){
	echo -n "error: "
	echo $1
	exit 1
}


# check if in debian like system
if test ! -f /etc/debian_version ; then
	ferror "refusing to build on a non-debian like system"
fi


# show help
if test $# -eq 0 ;then
	echo "Script to build all deb/rpm packages, and all apt server files."
	echo
	echo "Usage:"
	echo "  build_all.sh \"dmd1_version\" \"dmd2_version\"" 
	echo
	echo "Options:"
	echo "  (both arguments are mandatory)"
	exit
fi


# check number of parameters
if test $# -gt 2 ;then
	ferror "too many arguments"
elif test $# -lt 2 ;then
	ferror "too few arguments"
fi


# check version parameter
if ! [[ $1 =~ ^[0-9]"."[0-9][0-9][0-9]$ ]] ;then
	ferror "first arg.: incorrect version number"
elif test ${1:0:1}${1:2} -lt 1073 -o ${1:0:1} -gt 1 ;then
	ferror "first arg.: dmd1 v1.073 and newer only"
fi
if ! [[ $2 =~ ^[0-9]"."[0-9][0-9][0-9]$ ]] ;then
	ferror "second arg.: incorrect version number"
elif test ${2:0:1}${2:2} -lt 2058 -o ${2:0:1} -gt 2 ;then
	ferror "second arg.: dmd2 v2.058 and newer only"
fi


# run all scripts with arguments
echo "$DESTDIR/dmd_deb.sh -v$1" >$LOGFILE
#$DESTDIR/dmd_deb.sh -v$1

echo "$DESTDIR/dmd_deb.sh -v$2" >>$LOGFILE
#$DESTDIR/dmd_deb.sh -v$2

echo "$DESTDIR/dmd_rpm.sh -v$1" >>$LOGFILE
#$DESTDIR/dmd_rpm.sh -v$1

echo "$DESTDIR/dmd_rpm.sh -v$2" >>$LOGFILE
#$DESTDIR/dmd_rpm.sh -v$2

echo "$DESTDIR/dmd_arch.sh -v$1" >>$LOGFILE
#$DESTDIR/dmd_arch.sh -v$1

echo "$DESTDIR/dmd_arch.sh -v$2" >>$LOGFILE
$DESTDIR/dmd_arch.sh -v$2

echo "$DESTDIR/dmd_apt.sh -v$2" >>$LOGFILE
$DESTDIR/dmd_apt.sh -v$2


# if everything worked
echo -e "\neverything has been properly built!\n"


# remove log file
rm -f $LOGFILE
