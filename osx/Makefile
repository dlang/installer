# makefile to build OSX installer

# Externals
VER=2.057

TEMPDIR:=$(shell mktemp -d /tmp/dmd-installer.XXX)

all:
	curl http://ftp.digitalmars.com/dmd.${VER}.zip >${TEMPDIR}/dmd.${VER}.zip
	unzip ${TEMPDIR}/dmd.${VER}.zip -d ${TEMPDIR}
	rm -rf ${TEMPDIR}/dmd2/freebsd ${TEMPDIR}/dmd2/linux ${TEMPDIR}/dmd2/windows
	./make.rb -d ${TEMPDIR}/dmd2 -o ${TEMPDIR}/dmd.${VER}
	scp ${TEMPDIR}/dmd.${VER}.dmg d-programming@digitalmars.com:data/dmd.${VER}.dmg.tmp
	ssh d-programming@digitalmars.com "mv data/dmd.${VER}.dmg.tmp data/dmd.${VER}.dmg"
	rm -rf ${TEMPDIR}
