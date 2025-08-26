# -----------------------------------------------------------------------------
# Makefile — Ontology Build Pipeline (uses scripts/*)
# -----------------------------------------------------------------------------
# Usage:
#   make                # = help
#   make all            # generate → reason → report → validate
#   make generate
#   make reason         # REASONER=hermit make reason
#   make report         # FAIL_ON=WARN make report
#   make validate       # OWL_PROFILE=DL make validate
#   make release        # VERSION_TAG=2025-08-15 make release
#   make diff OLD=path/to/old.ttl NEW=path/to/new.ttl
#   make clean
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help all generate reason report validate release diff clean init-x

help:
	@echo "Ontology Build Pipeline"
	@echo
	@echo "Helper:"
	@echo "  import 	 : import external ontologies (see scripts/import.sh)"
	@echo
	@echo "Usage: [VARIABLE=value] make [target] "
	@echo "Targets:"
	@echo "  all         : generate → reason → report → validate"
	@echo "  generate    : expand TSV templates to TTL modules"
	@echo "  reason      : merge and classify ontology (use REASONER=hermit|ELK|jfact)"
	@echo "  report      : run QC (use FAIL_ON=ERROR|WARN|NONE)"
	@echo "  validate    : validate OWL profile & verify (use OWL_PROFILE=EL|RL|QL|DL)"
	@echo "  release     : package versioned release (use VERSION_TAG=YYYY-MM-DD)"
	@echo "  diff        : ROBOT diff (requires OLD=... and NEW=...)"
	@echo "  clean       : remove build outputs (target/)"
	@echo
	@echo "Examples:"
	@echo "  REASONER=hermit make reason"
	@echo "  FAIL_ON=WARN make report"
	@echo "  VERSION_TAG=2025-08-15 make release"
	@echo "  make diff OLD=releases/2025-08-10/ontology.ttl NEW=target/merged.ttl"

# Optional: make scripts executable once
init-x:
	@chmod +x scripts/*.sh || true
	@echo "✓ scripts are executable"

all: generate reason report validate

generate:
	@./scripts/generate_from_templates.sh

import:
	@./scripts/import.sh
reason:
	@./scripts/reason.sh

report:
	@./scripts/report.sh

validate:
	@./scripts/validate.sh

# VERSION_TAG can be overridden: VERSION_TAG=2025-08-15 make release
release:
	@./scripts/release.sh

# Requires OLD and NEW variables pointing to ontology files
diff:
ifeq ($(strip $(OLD)),)
	$(error Please provide OLD=path/to/old.ttl)
endif
ifeq ($(strip $(NEW)),)
	$(error Please provide NEW=path/to/new.ttl)
endif
	@./scripts/diff.sh "$(OLD)" "$(NEW)"

clean:
	@rm -rf target
	@echo "✓ cleaned target/"

