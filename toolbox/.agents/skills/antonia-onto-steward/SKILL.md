---
name: antonia-onto-steward
description: Interactively turn ontology quality requirements into ROBOT-integrated controls, using external SHACL validation only for genuine shape constraints.
---

# ANTONIA ontology steward

Read the repository-root `AGENTS.md`, configured ontology sources, design
record, OBDA mapping, and existing quality controls. Read
[the control contract](references/control-contract.md) before authoring rules.

Require a clean worktree and a dedicated `antonia/onto-steward-<date>` branch
before writing. For each invariant, establish its rationale, severity, target,
positive example, and negative example.

## Use ROBOT as the control plane

- Prefer a maintained ROBOT report rule when it already expresses the
  requirement. Configure built-in rules in `qc/profile.txt`.
- Maintain project-specific controls as SPARQL queries under the configured
  checks directory. Every query is injected into the effective ROBOT profile,
  must return exactly `?entity ?property ?value`, and must return zero rows for
  conforming data. Use `?property` as a stable rule IRI and put actionable
  evidence in `?value`.
- Never implement a blocking SPARQL control as a separate `robot query` gate.
  The configured reports directory is reserved for non-blocking analytics.
- Use SHACL only when node/property-shape semantics add value that a ROBOT
  report rule does not provide. Store those shapes under `src/shapes/shacl/`;
  pySHACL remains the only external validation path and runs only when shape
  files exist.
- Do not duplicate the native `forbidden_iri` or `forbidden_equivalence` rule.
  The IRI rule is rendered from `BASE_IRI` and `INSTANCE_BASE_IRI` by
  `toolbox/report.sh`. The equivalence rule runs through `robot report` on each
  source before fusion, excluding only the ontology configured by `MAPPINGS`.
- Preserve project-specific rules and messages. Use stable shape and rule IRIs
  so findings remain comparable over time.

Run `make install-semantic-tools` only when SHACL shapes require pySHACL, then
run `make report`. Inspect the canonical ROBOT TSV/HTML report and, when
applicable, the SHACL RDF/text reports rather than relying only on the exit
code. Add focused conforming and non-conforming fixtures for new patterns.

Present the controls, test evidence, and Git diff. Do not commit, push, merge,
or publish.
