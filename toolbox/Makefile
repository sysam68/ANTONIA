# -----------------------------------------------------------------------------
# ANTONIA toolbox — ontology host build pipeline
# -----------------------------------------------------------------------------
# This file is distributed under host_root/toolbox/ and copied to
# host_root/Makefile by init_project.sh and update-antonia.sh.

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help all import install-robot install-semantic-tools update-antonia generate reason project-ql report validate test-imports test-qc test-profiles test-equivalences test-release release diff clean init-x progress java-conf init-project

help:
	@echo "Ontology Build Pipeline"
	@echo
	@echo "Helpers:"
	@echo "  install-robot: install ROBOT and Java 17 locally under .tools/"
	@echo "  install-semantic-tools: install OntoGPT, Ontop, JDBC, and pySHACL locally"
	@echo "  update-antonia: update from stable (script supports -dev and -version=<tag>)"
	@echo "  java-conf   : generate the ignored config/java.conf JVM profile"
	@echo "  init-project: initialize missing host project files"
	@echo "  progress    : run the complete pipeline with progress indicators"
	@echo "  import      : import external ontologies"
	@echo
	@echo "Targets:"
	@echo "  all         : generate → reason → project-ql → report → validate"
	@echo "  generate    : expand TSV templates to RDF/XML modules"
	@echo "  reason      : merge and classify ontology (use REASONER=hermit|ELK|jfact)"
	@echo "  project-ql  : derive the OWL 2 QL projection used by Ontop"
	@echo "  report      : run QC (use FAIL_ON=ERROR|WARN|NONE)"
	@echo "  validate    : validate the OWL 2 DL reference and OWL 2 QL projection"
	@echo "  test-imports: verify Release download and the merged import closure"
	@echo "  test-qc     : verify ontology-scoped quality-control rules"
	@echo "  test-profiles: execute the DL and QL profile tests"
	@echo "  test-equivalences: execute ontology equivalence contracts"
	@echo "  test-release: verify resumable ontology release publication"
	@echo "  release     : package the ontology release (VERSION_TAG=YYYY-MM-DD)"
	@echo "  diff        : ROBOT diff (requires OLD=... and NEW=...)"
	@echo "  clean       : remove ontology build outputs under tmp/"
	@echo
	@echo "Codex skills:"
	@echo "  /skills     : browse installed ANTONIA skills"
	@echo '  $$antonia-<command>: invoke the corresponding guarded Make workflow'
	@echo
	@echo "Examples:"
	@echo "  REASONER=hermit make reason"
	@echo "  FAIL_ON=WARN make report"
	@echo "  VERSION_TAG=2025-08-15 make release"
	@echo "  make diff OLD=releases/old.rdf NEW=tmp/classified.rdf"
	@echo '  $$antonia-release VERSION_TAG=2025-08-15'

init-x:
	@chmod +x toolbox/*.sh || true
	@echo "✓ toolbox scripts are executable"

init-project:
	@bash toolbox/init_project.sh

all: generate reason project-ql report validate

progress:
	@bash -euo pipefail -c 'source ./toolbox/progress.sh; total=5; progress_step 1 $$total "generate"; progress_bar 1 $$total "generate"; make generate; printf "\n"; progress_step 2 $$total "reason"; progress_bar 2 $$total "reason"; make reason; printf "\n"; progress_step 3 $$total "project-ql"; progress_bar 3 $$total "project-ql"; make project-ql; printf "\n"; progress_step 4 $$total "report"; progress_bar 4 $$total "report"; make report; printf "\n"; progress_step 5 $$total "validate"; progress_bar 5 $$total "validate"; make validate; printf "\n"; echo "✓ Full pipeline complete"'

java-conf:
	@./toolbox/java_conf.sh

generate:
	@./toolbox/generate_from_templates.sh

import:
	@./toolbox/import.sh

install-robot:
	@./toolbox/install_robot.sh

install-semantic-tools:
	@./toolbox/install_semantic_tools.sh

update-antonia:
	@./toolbox/update-antonia.sh

reason:
	@./toolbox/reason.sh

project-ql:
	@./toolbox/project_ql.sh

report:
	@./toolbox/report.sh

validate:
	@./toolbox/validate.sh

test-profiles:
	@./tests/robot/owl2_dl_profile.test.sh
	@./tests/robot/owl2_ql_profile.test.sh

test-equivalences:
	@./tests/robot/business_area_domain_equivalence.test.sh
	@./tests/robot/service_domain_equivalence.test.sh

test-imports:
	@./tests/robot/import_release.test.sh
	@./tests/robot/import_closure.test.sh

test-qc:
	@./tests/robot/duplicate_label_scope.test.sh

test-release:
	@./tests/robot/release_idempotency.test.sh
	@./tests/robot/mapping_ontology.test.sh

release:
	@./toolbox/release.sh

diff:
ifeq ($(strip $(OLD)),)
	$(error Please provide OLD=path/to/old.rdf)
endif
ifeq ($(strip $(NEW)),)
	$(error Please provide NEW=path/to/new.rdf)
endif
	@./toolbox/diff.sh "$(OLD)" "$(NEW)"

clean:
	@rm -rf tmp
	@echo "✓ cleaned tmp/"
