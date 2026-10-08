---
name: antonia-onto-steward
description: Own the complete ANTONIA make-all pipeline and turn ontology quality requirements into ROBOT-integrated controls, using SHACL only for genuine shape constraints.
---

# ANTONIA ontology steward

Own the complete non-import ontology build and quality pipeline. Read the
repository-root `AGENTS.md`, `config/config.env`, configured ontology sources,
design record, OBDA mapping, and existing quality controls. Read
[the control contract](references/control-contract.md) before authoring rules.

Require a clean worktree and a dedicated `antonia/onto-steward-<date>` branch
before writing or changing controls. Do not require a clean worktree merely to
validate reviewed ontology or mapping changes already present on a dedicated
branch. For each invariant, establish its rationale, severity, target, positive
example, and negative example.

## Resolve the project paths before writing

Read `config/config.env` and resolve relative values from the repository root.
The authoritative locations are:

- `PROFILE` for the tab-separated control activation profile;
- `SPARQL_CHECKS` for blocking project `.rq` controls;
- `SPARQL_REPORTS` for non-blocking analytics only;
- `SHAPES_DIR` for optional SHACL files;
- `TARGET` for generated reports and temporary evidence.

Do not assume the default `qc/`, `src/sparql/`, `src/shapes/`, or `tmp/` paths.
Never write a project control under `toolbox/checks/`; that directory contains
ANTONIA-distributed examples only.

For every new or updated SPARQL control:

1. choose a stable file-base control name using letters, digits, `_`, or `-`;
2. write `<SPARQL_CHECKS>/<control-name>.rq` with exactly the projected
   variables `?entity ?property ?value`;
3. run the managed installer to validate the query and upsert its activation:

   ```bash
   python3 .agents/skills/antonia-onto-steward/scripts/install_control.py \
     --config config/config.env \
     --name <control-name> \
     --severity ERROR \
     --scope post-reason \
     --query <SPARQL_CHECKS>/<control-name>.rq
   ```

The installer creates the configured checks/profile parent directories when
missing, copies the query only to the configured checks directory, and keeps
exactly one tab-separated profile row. Re-running it updates severity or scope
without duplicating activation. Use `project-source` for project-owned sources,
`non-mapping-source` for every source except `MAPPINGS`, and `post-reason` for
the classified graph. Always record the scope explicitly.

For a genuine SHACL constraint, create `SHAPES_DIR` when missing and write a
stable `.ttl`, `.rdf`, or `.owl` shape file there. Do not add SHACL filenames to
`PROFILE`: `make report` discovers supported shape files recursively under the
configured directory. Do not place shapes under `SPARQL_CHECKS` or analytics
under `SHAPES_DIR`.

## Use ROBOT as the control plane

- Prefer a maintained ROBOT report rule when it already expresses the
  requirement. Configure built-in rules in the file configured by `PROFILE`.
- Maintain project-specific controls as SPARQL queries under the configured
  checks directory. Every query is injected into the effective ROBOT profile,
  must return exactly `?entity ?property ?value`, and must return zero rows for
  conforming data. Use `?property` as a stable rule IRI and put actionable
  evidence in `?value`.
- Never implement a blocking SPARQL control as a separate `robot query` gate.
  The configured reports directory is reserved for non-blocking analytics.
- Use SHACL only when node/property-shape semantics add value that a ROBOT
  report rule does not provide. Store those shapes under the configured
  `SHAPES_DIR`;
  pySHACL remains the only external validation path and runs only when shape
  files exist.
- Do not duplicate the native `example-forbidden_iri` or
  `example-forbidden_equivalence` rule.
  The IRI rule is rendered from `BASE_IRI` and `INSTANCE_BASE_IRI` by
  `toolbox/reason.sh`. The equivalence rule runs through `robot report` on each
  source before fusion, excluding only the ontology configured by `MAPPINGS`.
- Preserve project-specific rules and messages. Use stable shape and rule IRIs
  so findings remain comparable over time.

## Pilot the complete make-all chain

The steward is the single skill responsible for the complete `make all`
workflow. Do not delegate its individual stages to separate skills. Preserve
every Make assignment explicitly supplied by the user, including `REASONER`,
`FAIL_ON`, and `SHACL_FAIL_ON`, and run from the ontology repository root:

```bash
make all REASONER=<configured-or-requested> FAIL_ON=<requested-threshold> \
  SHACL_FAIL_ON=<requested-threshold>
```

Omit assignments that were neither requested nor already configured. Do not
silently weaken validation thresholds. `make all` executes, in order:

1. `generate` — expand configured TSV templates;
2. `reason` — run source-scoped controls, merge, and classify;
3. `project-ql` — build the OWL 2 QL projection;
4. `report` — run post-reason ROBOT controls and optional SHACL validation;
5. `validate` — validate the DL reference and QL projection.

Stop at the first failing stage. Diagnose that stage from its command output
and configured `TARGET` artifacts; do not claim that later stages ran. After a
successful run, inspect the generated ontology artifacts, canonical ROBOT
TSV/HTML report, and, when applicable, SHACL RDF/text reports instead of relying
only on the exit code. Report the effective reasoner and severity thresholds.

`make all` intentionally excludes dependency import, focused regression tests,
release packaging, and publication. Use their dedicated skills only when the
user requests those workflows. Run `make install-semantic-tools` only when
SHACL shapes require pySHACL. Add focused conforming and non-conforming fixtures
for new control patterns before running the complete chain.

Present the controls, test evidence, and Git diff. Do not commit, push, merge,
or publish.
