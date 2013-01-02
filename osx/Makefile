# Makefile to build OSX installer. Run make -j for building both dmd1
# and dmd2 versions in parallel. See the definition of VERSIONS for
# what versions are processed. To pass versions from the outside, run
# e.g.:
#
# make VERSIONS="2.058 1.073" -j
#

# Externals
VERSIONS=2.059 1.074
TARGET_SITE=d-programming@digitalmars.com
TARGET_DIR=data
# TARGET_SITE=erdani.com
# TARGET_DIR=d

TEMPDIR:=$(shell mktemp -d /tmp/dmd-installer.XXX)

MAKER:=$(shell \
if [ -f /Developer/usr/bin/packagemaker ];\
	then echo /Developer/usr/bin/packagemaker;\
	else echo /Applications/PackageMaker.app/Contents/MacOS/PackageMaker;\
fi)

all: ${VERSIONS}
	rm -rf ${TEMPDIR}

define MAIN
$1:
	rm -rf ${TEMPDIR}/dmd.$1*.zip ${TEMPDIR}/dmd.$1* dmd dmg
	curl --silent http://ftp.digitalmars.com/dmd.$1.zip >${TEMPDIR}/dmd.$1.zip
	unzip -q ${TEMPDIR}/dmd.$1.zip -d ${TEMPDIR}/$1
	rm -rf $(addprefix ${TEMPDIR}/$1/*/,freebsd linux windows bin)
	mkdir -p dmd
	cp -r $(addprefix ${TEMPDIR}/$1/dmd*/,html license.txt man README.TXT license.txt samples src osx/bin osx/lib) dmd/
	cp dmd$2.conf dmd/bin/dmd.conf
	mkdir -p dmg/DMD$2
	cp uninstall.command dmg/DMD$2/
	${MAKER} -d dmd$2.pmdoc -o dmg/DMD2/DMD$2.pkg
	hdiutil create -srcfolder dmg/DMD$2 ${TEMPDIR}/dmd.$1.dmg
	scp ${TEMPDIR}/dmd.$1.dmg ${TARGET_SITE}:${TARGET_DIR}/dmd.$1.dmg.tmp
	ssh ${TARGET_SITE} "mv ${TARGET_DIR}/dmd.$1.dmg.tmp ${TARGET_DIR}/dmd.$1.dmg"
endef

$(foreach VER,$(VERSIONS),$(eval $(call MAIN,$(VER),$(firstword $(subst ., ,$(VER))))))

