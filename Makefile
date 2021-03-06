#!/usr/bin/make -f

ACTIVE-LIST := $(wildcard active-keys/*.asc)
REMOVED-LIST := $(wildcard removed-keys/*.asc)
SUPPORTING-LIST := $(wildcard supporting-keys/*.asc)

KEYRINGS := \
	$(if $(ACTIVE-LIST),keyrings/deb.n-1.fi-archive-keyring.gpg,) \
	$(if $(REMOVED-LIST),keyrings/deb.n-1.fi-archive-removed-keys.gpgm,)

GPG_HOME := build-gpg-home
GPG_OPTIONS := --no-options --no-default-keyring --no-auto-check-trustdb --trustdb-name ./trustdb.gpg

PACKAGE_NAME := $(shell dpkg-parsechangelog -ldebian/changelog -S Source)
PACKAGE_VERSION := $(shell dpkg-parsechangelog -ldebian/changelog -S Version)


$(GPG_HOME)/pubring.kbx: $(SUPPORTING-LIST)
	mkdir -p $(GPG_HOME)
	gpg --no-options --homedir $(GPG_HOME) --import $^

keyrings/deb.n-1.fi-archive-keyring.gpg: $(ACTIVE-LIST)
keyrings/deb.n-1.fi-archive-removed-keys.gpg: $(REMOVED-LIST)

keyrings/%.gpg:
	rm -f "$@"
	touch "$@" # this changes the storage from keybox to keyring..
	gpg ${GPG_OPTIONS} --keyring "$@" --import $^
	rm -f "$@~"
	gpg ${GPG_OPTIONS} --no-keyring --import-options import-export --import "$@" > "$@.tmp"
	mv -f "$@.tmp" "$@"


verify-results: $(KEYRINGS) | $(GPG_HOME)/pubring.kbx
	for keyring in $`; do \
		gpg --no-options --homedir $(GPG_HOME) \
			--keyring $$keyring \
			--check-signatures ; \
	done
	# TODO: check for missing keys


clean:
	rm -f $(KEYRINGS) keyrings/*.cache
	rm -rf $(GPG_HOME) trustdb.gpg

clean-releases:
	rm -vf ../$(PACKAGE_NAME)_*.tar.* \
		../$(PACKAGE_NAME)_*.dsc \
		../$(PACKAGE_NAME)_*_*.build \
		../$(PACKAGE_NAME)_*_*.buildinfo \
		../$(PACKAGE_NAME)_*_*.changes
	for pkg in $(shell dh_listpackages); do rm -vf ../$${pkg}_*_*.deb; done

build: $(KEYRINGS) verify-results

install: $(KEYRINGS) verify-results
	install -d $(DESTDIR)/usr/share/keyrings/
	cp $(KEYRINGS) $(DESTDIR)/usr/share/keyrings/


build-release:
	debuild

build-local:
	dch -t -l~test "Local test build: $(shell date)"
	debuild -uc -us

upload: build-release
	@echo Uploading changes to the remote, see ~/.dupload.conf
	for changes in ../$(PACKAGE_NAME)_$(PACKAGE_VERSION)_*.changes; do \
		dupload -t deb.n-1.fi $$changes ; \
	done


.PHONY: verify-results clean clean-releases build install build-release build-local upload
