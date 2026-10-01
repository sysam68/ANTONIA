# -----------------------------------------------------------------------------
# ANTONIA repository lifecycle
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.DEFAULT_GOAL := help

VERSION ?=

.PHONY: help check test test-agent-skills test-config-update test-semantic-authoring test-database-integration test-package test-lifecycle package release clean

help:
	@echo "ANTONIA Toolbox"
	@echo
	@echo "Targets:"
	@echo "  check              validate shell syntax and repository structure"
	@echo "  test               run all ANTONIA tests"
	@echo "  test-agent-skills  verify Make target coverage by distributed skills"
	@echo "  test-config-update verify additive configuration migration"
	@echo "  test-semantic-authoring verify semantic skills and helper safety"
	@echo "  test-database-integration verify PostgreSQL/MySQL sampling and Ontop bootstrap"
	@echo "  test-package       verify the distributable toolbox archive"
	@echo "  test-lifecycle     verify bootstrap cleanup and in-toolbox updates"
	@echo "  package            build Release assets (VERSION=<tag>)"
	@echo "  release            tag and publish ANTONIA (VERSION=<tag>)"
	@echo "  clean              remove locally generated Release assets"
	@echo
	@echo "Examples:"
	@echo "  make test"
	@echo "  make package VERSION=v1.0.0"
	@echo "  make release VERSION=v1.0.0"

check:
	@for script in install-antonia.sh update-antonia.sh package-antonia.sh release-antonia.sh toolbox/*.sh tests/robot/*.sh tests/data/install-robot-stub.sh; do \
		bash -n "$$script"; \
	done
	@test -f toolbox/Makefile
	@test -f toolbox/AGENTS.md
	@test -f toolbox/.agents/.antonia-managed
	@test -x toolbox/sync_agents.sh
	@while IFS= read -r line || [ -n "$$line" ]; do \
		case "$$line" in \
			skill=*) skill_path="$${line#skill=}"; \
				test -f "toolbox/.agents/$$skill_path/SKILL.md" ;; \
		esac; \
	done < toolbox/.agents/.antonia-managed
	@test -f toolbox/templates/config/config.env
	@if grep -Eq '^[[:space:]]*source .*common\.sh' toolbox/install_robot.sh; then \
		echo "Error: install_robot.sh must not require common.sh before bootstrap" >&2; \
		exit 1; \
	fi
	@python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("toolbox").rglob("*.py")]'
	@echo "ANTONIA checks: passed"

test: check test-agent-skills test-config-update test-semantic-authoring test-lifecycle

test-agent-skills:
	@./tests/robot/agent-skills.test.sh

test-config-update:
	@./tests/robot/config-update.test.sh

test-semantic-authoring:
	@./tests/robot/semantic-authoring.test.sh

test-database-integration:
	@./tests/robot/database-sampling.integration.sh

test-package:
	@./package-antonia.sh test-local
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/Makefile$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/AGENTS.md$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/.agents/.antonia-managed$$'
	@while IFS= read -r line || [ -n "$$line" ]; do \
		case "$$line" in \
			skill=*) skill_path="$${line#skill=}"; \
				tar -tzf dist/antonia-toolbox.tar.gz \
					| grep -q "^toolbox/.agents/$$skill_path/SKILL.md$$" ;; \
		esac; \
	done < toolbox/.agents/.antonia-managed
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/install-antonia.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/update-antonia.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/install_robot.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/install_semantic_tools.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/validate_shacl.py$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/validate_ontogpt_output.py$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/sample_database.py$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/run_ontogpt.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/templates/config/ontop.properties.example$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/.agents/skills/antonia-ontologist/assets/antonia_ontology_candidates.yaml$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/sync_agents.sh$$'
	@tar -xOf dist/antonia-toolbox.tar.gz toolbox/Makefile | grep -q '^update-antonia:'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/update_config.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/templates/config/config.env$$'
	@if tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/toolbox/'; then \
		echo "Error: double toolbox directory detected" >&2; \
		exit 1; \
	fi
	@if tar -tzf dist/antonia-toolbox.tar.gz | grep -Eq '\.properties$$'; then \
		echo "Error: datasource properties file packaged" >&2; \
		exit 1; \
	fi
	@echo "ANTONIA package test: passed"

test-lifecycle: test-package
	@./tests/robot/lifecycle-scripts.test.sh

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
