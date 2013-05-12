# Makefile to build OSX installer. Just run without arguments to build
# the latest version, or pass ${VERSION} to build a specific version,
# e.g.
#
# make VERSION="2.067"
#

# Externals
ifeq (,${VERSION})
  DMDPATH=${CURDIR}/../../dmd
  VERSION:=$(shell cat ${DMDPATH}/VERSION)
  ifeq (,${VERSION})
    $(error Cannot find dmd version file ${DMDPATH}/VERSION)
  endif
endif
TARGET_SITE=d-programming@digitalmars.com
TARGET_DIR=data
# TARGET_SITE=erdani.com
# TARGET_DIR=d

MAKER:=$(shell \
if [ -f /Developer/usr/bin/packagemaker ];\
	then echo /Developer/usr/bin/packagemaker;\
	else echo /Applications/PackageMaker.app/Contents/MacOS/PackageMaker;\
fi)

all: dmd.${VERSION}.dmg
	rsync -az $< ${TARGET_SITE}:${TARGET_DIR}/dmd.${VERSION}.dmg

dmd.${VERSION}.zip:
	curl --progress-bar ftp://ftp.digitalmars.com/dmd.${VERSION}.zip >$@.tmp
	mv $@.tmp $@

dmd.${VERSION}.dmg: dmd.${VERSION}.zip
	rm -rf dmd
	mkdir -p dmd
	unzip -q dmd.${VERSION}.zip -d dmd/
	mv $(addprefix dmd/dmd2/,html license.txt man README.TXT samples src osx/bin osx/lib) dmd/
	rm -rf dmd/dmd2/
	cp dmd2.conf dmd/bin/dmd.conf
	rm -rf dmg/
	mkdir -p dmg/DMD2
	cp uninstall.command dmg/DMD2/
	${MAKER} -d dmd$2.pmdoc -o dmg/DMD2/DMD2.pkg --target 10.5
	hdiutil create -srcfolder dmg/DMD2 $@

clean:
	rm -rf dmd.*.zip dmd.*.dmg dmd.*.tmp

