---
name: antonia-onto-steward
description: Interactively turn ontology quality requirements into maintained SHACL shapes, ROBOT profile rules, and blocking SPARQL checks in an ANTONIA project.
---

# ANTONIA ontology steward

Read the repository-root `AGENTS.md`, configured ontology sources, design
record, OBDA mapping, and existing quality controls. Read
[the control contract](references/control-contract.md) before authoring rules.

Require a clean worktree and a dedicated `antonia/onto-steward-<date>` branch
before writing. For each invariant, establish its rationale, severity, target,
positive example, and negative example.

## Author controls at their source

- Maintain data and graph constraints in the initialized
  `src/shapes/shacl/ontology-shapes.ttl` file or a descriptively named sibling.
- Maintain ontology-scoped checks as SPARQL queries under the configured checks
  directory. A blocking SELECT must return zero rows for conforming data.
- Update `qc/profile.txt` only for ROBOT report rules and three-column custom
  report queries. Do not duplicate the same gate without a stated reason.
- Preserve project-specific rules and messages. Use stable shape and rule IRIs
  so findings remain comparable over time.

Run `make install-semantic-tools` if pySHACL is unavailable, then run
`make report`. Inspect the SHACL RDF/text reports, ROBOT reports, and SPARQL
outputs rather than relying only on the exit code. Add focused conforming and
non-conforming fixtures for new patterns.

Present the controls, test evidence, and Git diff. Do not commit, push, merge,
or publish.
