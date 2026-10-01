# -----------------------------------------------------------------------------
# ANTONIA repository lifecycle
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.DEFAULT_GOAL := help

VERSION ?=

.PHONY: help check test test-config-update test-package package release clean

help:
	@echo "ANTONIA Toolbox"
	@echo
	@echo "Targets:"
	@echo "  check              validate shell syntax and repository structure"
	@echo "  test               run all ANTONIA tests"
	@echo "  test-config-update verify additive configuration migration"
	@echo "  test-package       verify the distributable toolbox archive"
	@echo "  package            build Release assets (VERSION=<tag>)"
	@echo "  release            tag and publish ANTONIA (VERSION=<tag>)"
	@echo "  clean              remove locally generated Release assets"
	@echo
	@echo "Examples:"
	@echo "  make test"
	@echo "  make package VERSION=v1.0.0"
	@echo "  make release VERSION=v1.0.0"

check:
	@for script in install-antonia.sh update-antonia.sh package-antonia.sh release-antonia.sh toolbox/*.sh tests/robot/*.sh; do \
		bash -n "$$script"; \
	done
	@test -f toolbox/Makefile
	@test -f toolbox/templates/config/config.env
	@echo "ANTONIA checks: passed"

test: check test-config-update test-package

test-config-update:
	@./tests/robot/config-update.test.sh

test-package:
	@./package-antonia.sh test-local
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/Makefile$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/update_config.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/templates/config/config.env$$'
	@if tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/toolbox/'; then \
		echo "Error: double toolbox directory detected" >&2; \
		exit 1; \
	fi
	@echo "ANTONIA package test: passed"

package:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION=<release-tag> is required." >&2; \
		exit 2; \
	fi
	@./package-antonia.sh "$(VERSION)"

release:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION=<release-tag> is required." >&2; \
		exit 2; \
	fi
	@./release-antonia.sh "$(VERSION)"

clean:
	@rm -f dist/antonia-toolbox.tar.gz dist/antonia-toolbox.tar.gz.sha256
	@rmdir dist 2>/dev/null || true
	@echo "ANTONIA local Release assets removed"
