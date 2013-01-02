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

MAKER:=$(shell \
if [ -f /Developer/usr/bin/packagemaker ];\
	then echo /Developer/usr/bin/packagemaker;\
	else echo /Applications/PackageMaker.app/Contents/MacOS/PackageMaker;\
fi)

all: ${VERSIONS}

clean:
	rm -rf dmd.*.zip dmd.*.dmg

define MAIN
dmd.$1.zip:
	curl --silent --time-cond $$@ http://ftp.digitalmars.com/dmd.$1.zip >$$@.tmp
	mv $$@.tmp $$@

dmd.$1.dmg: dmd.$1.zip
	rm -rf dmd
	mkdir -p dmd
	unzip -q dmd.$1.zip -d dmd/
	mv $(addprefix dmd/dmd$2/,html license.txt man README.TXT samples src osx/bin osx/lib) dmd/
	rm -rf dmd/dmd$2/
	cp dmd$2.conf dmd/bin/dmd.conf
	rm -rf dmg/
	mkdir -p dmg/DMD$2
	cp uninstall.command dmg/DMD$2/
	${MAKER} -d dmd$2.pmdoc -o dmg/DMD2/DMD$2.pkg
	hdiutil create -srcfolder dmg/DMD$2 $$@

$1: dmd.$1.dmg
	rsync -az $$< ${TARGET_SITE}:${TARGET_DIR}/dmd.$1.dmg
endef

$(foreach VER,$(VERSIONS),$(eval $(call MAIN,$(VER),$(firstword $(subst ., ,$(VER))))))

