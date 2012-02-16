# Makefile to build OSX installer. Run make -j for building both dmd1
# and dmd2 versions in parallel. See the definition of VERSIONS for
# what versions are processed. To pass versions from the outside, run
# e.g.:
#
# make VERSIONS="2.058 1.073" -j
#

# Externals
VERSIONS=2.058 1.073
TARGET_SITE=d-programming@digitalmars.com
TARGET_DIR=data/
# TARGET_SITE=erdani.com
# TARGET_DIR=d

TEMPDIR:=$(shell mktemp -d /tmp/dmd-installer.XXX)

all: ${VERSIONS}
	rm -rf ${TEMPDIR}

define MAIN
$1:
	curl --silent http://ftp.digitalmars.com/dmd.$1.zip >${TEMPDIR}/dmd.$1.zip
	unzip -q ${TEMPDIR}/dmd.$1.zip -d ${TEMPDIR}/$1
	rm -rf ${TEMPDIR}/$1/*/freebsd ${TEMPDIR}/$1/*/linux ${TEMPDIR}/$1/*/windows
	./make.rb -d ${TEMPDIR}/$1/dmd* -o ${TEMPDIR}/dmd.$1
	scp ${TEMPDIR}/dmd.$1.dmg ${TARGET_SITE}:${TARGET_DIR}/dmd.$1.dmg.tmp
	ssh ${TARGET_SITE} "mv ${TARGET_DIR}/dmd.$1.dmg.tmp ${TARGET_DIR}/dmd.$1.dmg"
endef

$(foreach VER,$(VERSIONS),$(eval $(call MAIN,$(VER))))

