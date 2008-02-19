ifeq (,$(VER))
    $(error You must define VER, for example: `sudo make VER=2.100`)
endif

all: pkg

MY_WORK_DIR=$(shell pwd)
export MY_WORK_DIR

pkg:
	@./prep.sh
	@./mkspec.sh $(VER) > /usr/src/rpm/SPECS/dmd.spec
	cp dmd.$(VER).zip /usr/src/rpm/SOURCES
	cd /usr/src/rpm && rpmbuild -bb -v SPECS/dmd.spec
