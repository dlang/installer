VERSION=2.062
RELEASE=0
ARCHS=i386 x86_64

RPM_TOP_DIR=$(shell rpm --eval '%_topdir')
RPMS_DIR=$(RPM_TOP_DIR)/RPMS
SRC_DIR=$(RPM_TOP_DIR)/SOURCES

BUILD_SPEC_FILE=$(RPM_TOP_DIR)/SPECS/dmd-$(VERSION)-$(RELEASE).spec

BUILT_RPMS=$(foreach arch,$(ARCHS),$(RPMS_DIR)/$(arch)/dmd-$(VERSION)-$(RELEASE).$(arch).rpm)
SRC_FILES=$(foreach arch,$(ARCHS),$(SRC_DIR)/dmd-$(VERSION)-$(RELEASE)-$(arch).pkg.tar.xz)

RPMS=$(notdir $(BUILT_RPMS))

all: $(RPMS)

$(RPMS): $(BUILT_RPMS)
	for rpm in $(BUILT_RPMS); do \
		cp $$rpm . ; \
	done

$(BUILT_RPMS): $(BUILD_SPEC_FILE) $(SRC_FILES)
	for arch in $(ARCHS); do \
		rpmbuild -bb --target $$arch $<; \
	done

$(SRC_DIR)/%.pkg.tar.xz:
	wget --no-check-certificate -O $@ ftp://www.digitalmars.com/$(notdir $@)

$(BUILD_SPEC_FILE): dmd.spec Makefile
	VERSION=$(VERSION); \
	RELEASE=$(RELEASE); \
	sed -e "s/^Version: .*/Version: $$VERSION/" \
		-e "s/^Release: .*/Release: $$RELEASE/" \
		dmd.spec > $(BUILD_SPEC_FILE)

clean:
	rm -f $(BUILD_SPEC_FILE)

veryclean: clean
	rm -f $(BUILT_RPMS)
