# makefile to build OSX installer

# Externals
VER=2.057

TEMPDIR:=$(shell echo /tmp/dmd-installer.$$RANDOM.$$RANDOM.$$RANDOM)

all:
	mkdir ${TEMPDIR}
	cd ${TEMPDIR} && curl http://ftp.digitalmars.com/dmd.${VER}.zip >dmd.${VER}.zip
	cd ${TEMPDIR} && unzip dmd.${VER}.zip
	cd ${TEMPDIR} && rm -rf dmd2/freebsd dmd2/linux dmd2/windows
	./make.rb -d ${TEMPDIR}/dmd2 -o ${TEMPDIR}/dmd.${VER}
	scp ${TEMPDIR}/dmd.${VER}.dmg d-programming@digitalmars.com:data/dmd.${VER}.dmg
	rm -rf ${TEMPDIR}
