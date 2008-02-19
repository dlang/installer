#! /bin/bash
# Check for apt-get, alien, wget, then download dmd.zip
#
if test -n "`which apt-get`"; then 
	echo "Cool, apt-get detected."
	echo "Checking alien..."

	if test -z "`which alien`"; then 
		apt-get install alien
	fi
	echo "Checking wget..."
	if test -z "`which wget`"; then 
		apt-get install wget
	fi
fi

test -f dmd.${VER}.zip || wget http://ftp.digitalmars.com/dmd.${VER}.zip
