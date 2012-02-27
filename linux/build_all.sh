#!/bin/bash


set -e


# set variables
DESTDIR=`dirname $0`
LOGFILE="build_all.log"
SPACER="\n`seq -s "#" 77 | sed 's/[0-9]//g'`\n"


# error function
ferror(){
	echo -n "error: " >&2
	echo $1 >&2
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
	echo "  build_all.sh \"dmd1_version\" \"dmd2_version\" [-f]" 
	echo
	echo "Options:"
	echo "  (first and second arguments are mandatory)"
	echo "  -f       force to rebuild"
	exit
fi


# check number of parameters
if test $# -gt 3 ;then
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


# check forced build parameter
if test $# -eq 3 -a "$3" != "-f" ;then
	ferror "unknown third argument (-f)"
fi


# build dmd1 deb 32-bit
COMMAND="$DESTDIR/dmd_deb.sh -v$1 -m32 $3"
echo -e "$SPACER$COMMAND" >$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd1 deb 64-bit
COMMAND="$DESTDIR/dmd_deb.sh -v$1 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 deb 32-bit
COMMAND="$DESTDIR/dmd_deb.sh -v$2 -m32 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 deb 64-bit
COMMAND="$DESTDIR/dmd_deb.sh -v$2 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd1 rpm 32-bit
COMMAND="$DESTDIR/dmd_rpm.sh -v$1 -m32 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd1 rpm 64-bit
COMMAND="$DESTDIR/dmd_rpm.sh -v$1 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 rpm 32-bit
COMMAND="$DESTDIR/dmd_rpm.sh -v$2 -m32 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 rpm 64-bit
COMMAND="$DESTDIR/dmd_rpm.sh -v$2 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd1 arch 32-bit
COMMAND="$DESTDIR/dmd_arch.sh -v$1 -m32 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd1 arch 64-bit
COMMAND="$DESTDIR/dmd_arch.sh -v$1 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 arch 32-bit
COMMAND="$DESTDIR/dmd_arch.sh -v$2 -m32 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build dmd2 arch 64-bit
COMMAND="$DESTDIR/dmd_arch.sh -v$2 -m64 $3"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# build apt folder/files
COMMAND="$DESTDIR/dmd_apt.sh -v$2"
echo -e "$SPACER$COMMAND" >>$LOGFILE
$COMMAND 2> >(tee -a $LOGFILE >&2)


# if everything went well
echo -e "\nEverything properly built!\n"


# remove log file
rm -f $LOGFILE

