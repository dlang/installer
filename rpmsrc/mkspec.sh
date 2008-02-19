#! /bin/bash
DATE=`date +%m%d%y`

if test $# -lt 1; then
	echo Version argument missing
	exit 1
fi

echo "s/@DATE/$DATE/;s/@DISASM/$DISASM/;\
	  s/@VERSION/$1/" | \
sed --file - spec.template
