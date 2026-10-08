# -----------------------------------------------------------------------------
# ANTONIA repository lifecycle
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.DEFAULT_GOAL := help

VERSION ?=

.PHONY: help check test test-agent-skills test-config-update test-import-release test-reason-empty test-equivalence-scope test-iri-scope test-report-integration test-semantic-authoring test-database-integration test-release-channels test-release-mapping test-package test-lifecycle package release prerelease clean

help:
	@echo "ANTONIA Toolbox"
	@echo
	@echo "Targets:"
	@echo "  check              validate shell syntax and repository structure"
	@echo "  test               run all ANTONIA tests"
	@echo "  test-agent-skills  verify Make target coverage by distributed skills"
	@echo "  test-config-update verify additive configuration migration"
	@echo "  test-import-release verify latest and explicit GitHub Release imports"
	@echo "  test-reason-empty  verify that absent ontology inputs are a valid no-op"
	@echo "  test-equivalence-scope verify equivalences are confined to MAPPINGS"
	@echo "  test-iri-scope     verify IRI ownership before merge on local sources only"
	@echo "  test-report-integration verify ROBOT-native SPARQL control reporting"
	@echo "  test-semantic-authoring verify semantic skills and helper safety"
	@echo "  test-database-integration verify PostgreSQL/MySQL sampling and Ontop bootstrap"
	@echo "  test-release-channels verify stable and development publication guards"
	@echo "  test-release-mapping verify QL, OBDA, safe properties, mapping, and service assets"
	@echo "  test-package       verify the distributable toolbox archive"
	@echo "  test-lifecycle     verify bootstrap cleanup and in-toolbox updates"
	@echo "  package            build Release assets (VERSION=<tag>)"
	@echo "  release            tag and publish ANTONIA (VERSION=<tag>)"
	@echo "  prerelease         tag and publish ANTONIA from dev (VERSION=<tag>)"
	@echo "  clean              remove locally generated Release assets"
	@echo
	@echo "Examples:"
	@echo "  make test"
	@echo "  make package VERSION=v1.0.0"
	@echo "  make release VERSION=v1.0.0"
	@echo "  make prerelease VERSION=v1.1.0-dev.1"

check:
	@for script in install-antonia.sh update-antonia.sh package-antonia.sh release-antonia.sh toolbox/*.sh tests/robot/*.sh tests/data/install-robot-stub.sh; do \
		bash -n "$$script"; \
	done
	@test -f toolbox/Makefile
	@test -f toolbox/AGENTS.md
	@test -f toolbox/.agents/.antonia-managed
	@test -x toolbox/sync_agents.sh
	@test -x toolbox/sync_checks.sh
	@test -x toolbox/update_profile.sh
	@test -x toolbox/.agents/skills/antonia-onto-steward/scripts/install_control.py
	@while IFS= read -r line || [ -n "$$line" ]; do \
		case "$$line" in \
			skill=*) skill_path="$${line#skill=}"; \
				test -f "toolbox/.agents/$$skill_path/SKILL.md" ;; \
		esac; \
	done < toolbox/.agents/.antonia-managed
	@test -f toolbox/templates/config/config.env
	@test -f toolbox/qc/example-profile.txt
	@awk -F '\t' '\
		NF < 2 || NF > 3 { print "Error: invalid QC example profile field count at line " NR > "/dev/stderr"; exit 1 } \
		$$1 !~ /^(ERROR|WARN|INFO)$$/ { print "Error: invalid QC severity at line " NR > "/dev/stderr"; exit 1 } \
		$$2 !~ /^[A-Za-z0-9_-]+$$/ { print "Error: invalid QC control name at line " NR > "/dev/stderr"; exit 1 } \
		NF == 3 && $$3 !~ /^(project-source|non-mapping-source|post-reason)$$/ { print "Error: invalid QC scope at line " NR > "/dev/stderr"; exit 1 } \
		seen[$$2]++ { print "Error: duplicate QC control " $$2 > "/dev/stderr"; exit 1 } \
	' toolbox/qc/example-profile.txt
	@test -f toolbox/checks/example-forbidden_iri.rq
	@test -f toolbox/checks/example-forbidden_equivalence.rq
	@if find toolbox/checks -type f ! -name 'example-*.rq' -print -quit | grep -q .; then \
		echo "Error: every toolbox control example must match example-*.rq" >&2; \
		exit 1; \
	fi
	@test -x toolbox/clean.sh
	@if grep -Eq '^[[:space:]]*source .*common\.sh' toolbox/install_robot.sh; then \
		echo "Error: install_robot.sh must not require common.sh before bootstrap" >&2; \
		exit 1; \
	fi
	@if grep -En '\$$TARGET/(merged|classified|ontop-ql)\.(rdf|ttl|owl)' toolbox/*.sh; then \
		echo "Error: ontology output paths must use the canonical common.sh variables" >&2; \
		exit 1; \
	fi
	@python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("toolbox").rglob("*.py")]'
	@echo "ANTONIA checks: passed"

test: check test-agent-skills test-config-update test-import-release test-reason-empty test-equivalence-scope test-iri-scope test-report-integration test-semantic-authoring test-release-channels test-release-mapping test-lifecycle

test-agent-skills:
	@./tests/robot/agent-skills.test.sh

test-config-update:
	@./tests/robot/config-update.test.sh

test-import-release:
	@./tests/robot/import-release.test.sh

test-reason-empty:
	@./tests/robot/reason-empty-inputs.test.sh

test-equivalence-scope:
	@./tests/robot/equivalence-scope.test.sh

test-iri-scope:
	@./tests/robot/iri-scope.test.sh

test-report-integration:
	@./tests/robot/report-integration.test.sh

test-semantic-authoring:
	@./tests/robot/semantic-authoring.test.sh

test-database-integration:
	@./tests/robot/database-sampling.integration.sh

test-release-channels:
	@./tests/robot/release-channels.test.sh

test-release-mapping:
	@./tests/robot/release-mapping.test.sh
	@./tests/robot/release-services.test.sh
	@./tests/robot/release-versioning.test.sh

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
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/.agents/skills/antonia-onto-steward/scripts/install_control.py$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/sync_agents.sh$$'
	@tar -xOf dist/antonia-toolbox.tar.gz toolbox/Makefile | grep -q '^update-antonia:'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/update_config.sh$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/templates/config/config.env$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/qc/example-profile.txt$$'
	@cmp toolbox/qc/example-profile.txt \
		<(tar -xOf dist/antonia-toolbox.tar.gz toolbox/qc/example-profile.txt)
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/checks/example-forbidden_iri.rq$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/checks/example-forbidden_equivalence.rq$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/checks/forbidden_iri.rq$$'
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/checks/forbidden_equivalence.rq$$'
	@cmp <(tar -xOf dist/antonia-toolbox.tar.gz toolbox/checks/example-forbidden_iri.rq) \
		<(tar -xOf dist/antonia-toolbox.tar.gz toolbox/checks/forbidden_iri.rq)
	@cmp <(tar -xOf dist/antonia-toolbox.tar.gz toolbox/checks/example-forbidden_equivalence.rq) \
		<(tar -xOf dist/antonia-toolbox.tar.gz toolbox/checks/forbidden_equivalence.rq)
	@tar -tzf dist/antonia-toolbox.tar.gz | grep -q '^toolbox/clean.sh$$'
	@for script in toolbox/*.sh; do \
		script_name="$${script##*/}"; \
		tar -tzf dist/antonia-toolbox.tar.gz \
			| grep -q "^toolbox/$$script_name$$"; \
	done
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

prerelease:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION=<prerelease-tag> is required." >&2; \
		exit 2; \
	fi
	@./release-antonia.sh --prerelease "$(VERSION)"

clean:
	@rm -f dist/antonia-toolbox.tar.gz dist/antonia-toolbox.tar.gz.sha256
	@rmdir dist 2>/dev/null || true
	@echo "ANTONIA local Release assets removed"
