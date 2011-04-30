all: pkg

RPM_TOP_DIR=$(shell rpm --eval '%_topdir')
export RPM_TOP_DIR

pkg:
	cp dmd.conf d-completion.sh *.patch $(RPM_TOP_DIR)/SOURCES/
	cp dmd.spec $(RPM_TOP_DIR)/SPECS/
	rpmbuild -bb --target i386 $(RPM_TOP_DIR)/SPECS/dmd.spec
