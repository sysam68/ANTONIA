---
name: antonia-ontology-workflow
description: Develop and validate ontology sources, imports, mappings, templates, SHACL constraints, SPARQL quality rules, and releases in a repository managed by the ANTONIA toolbox.
---

# ANTONIA ontology workflow

Read the repository-root `AGENTS.md` before acting. Treat it as the authoritative
project guidance and use this skill for the task-specific workflow below.
For a request that maps to one Make target, prefer the matching
`$antonia-<command>` skill documented in `toolbox/docs/agent-skills.md`.

## Establish the active project contract

- Read `config/config.env` before naming ontology files, IRIs, build paths, or
  optional mapping and Ontop inputs.
- Read `config/import.env` and the XML catalog before changing an import.
- Inspect the working tree and preserve unrelated changes.
- Distinguish authoritative sources under `src/` from generated evidence under
  the configured `TARGET` and distributable artifacts under `releases/`.

## Make the change at its authoritative source

- Change ontology semantics in the configured editable ontology, mapping
  ontology, templates, SHACL shapes, or SPARQL rules as appropriate.
- Do not edit generated files under `TARGET` as source material.
- Do not hard-code names, IRIs, or paths from another ontology repository into
  the shared toolbox.
- Keep the OWL 2 DL reference ontology distinct from the derived OWL 2 QL
  projection used by Ontop.
- Declare class equivalences only in the ontology-to-ontology file configured
  by `MAPPINGS`; they are forbidden in every other ontology source.

## Validate proportionally

- For import or catalog changes, run `make import` and `make test-imports`.
- For ontology or pipeline changes, run `make all` and the relevant focused
  tests, normally `make test-profiles` and `make test-equivalences`.
- Inspect the reports under `TARGET` when validation fails; do not infer success
  from command execution alone.
- If Java or ROBOT is unavailable, run `make install-robot`. State clearly when
  full validation could not be completed.

## Respect publication boundaries

- Treat `make release` as an external publication operation.
- Run it only when the user explicitly asks to publish and the repository state
  satisfies the release contract in `AGENTS.md`.
- Report the exact commands run, verified outputs, remaining uncertainty, and
  semantic impact of the change.
