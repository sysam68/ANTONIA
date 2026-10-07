# Ontology Repository Guidelines

## Project structure

This repository maintains an ontology with the ANTONIA ROBOT toolbox. The
authoritative schema, optional ABox, optional ontology mapping, Ontop mapping,
catalog, and build paths are configured in `config/config.env`. Never hard-code
another ontology's names, IRIs, or source paths into the shared toolbox.

External dependencies are selected in `config/import.env` as GitHub Release
assets, downloaded into the configured imports directory, and resolved through
the configured XML catalog. Selectors may be immutable Release tags or
`latest`; the latter must resolve to a concrete tag and be reported during
import. Treat imported ontology files as versioned source dependencies, not as
build outputs.

Keep generated ontology modules in the configured modules directory, optional
SHACL constraints under `src/shapes/`, and SPARQL checks, analytics, and updates
under `src/sparql/`. Blocking SPARQL checks must be ROBOT report queries that
return exactly `?entity ?property ?value`; do not execute them as separate
`robot query` gates.

All ROBOT-control activation and severity configuration belongs exclusively in
`qc/profile.txt`. A control runs only when its exact file base name appears as
the second tab-separated field in that profile. The presence of an `.rq` file
does not activate it, and no control activation list belongs in `config.env`, a
Makefile, or a runtime script.

The optional third profile field defines execution scope: `project-source`,
`non-mapping-source`, or `post-reason`. An omitted scope means `post-reason`.
The distributed `toolbox/qc/example-profile.txt` lists every native ROBOT
report control plus the two ANTONIA source controls as a reference. It does not
activate controls in the project's `qc/profile.txt`.

Every control example distributed by ANTONIA lives under `toolbox/checks/` and
keeps its `example-` filename. Installation and update copy every example into
the directory configured by `SPARQL_CHECKS` without renaming it, while
preserving unrelated project controls. Transient build artifacts belong under
the configured `TARGET` (`tmp/` by default); distributable current and dated
packages belong in `releases/`.

The root `Makefile` and `AGENTS.md` are managed copies of `toolbox/Makefile` and
`toolbox/AGENTS.md`. Repository skills declared by
`toolbox/.agents/.antonia-managed` are managed copies under the root
`.agents/skills/`. ANTONIA updates replace those managed copies while preserving
unrelated project skills. Put reusable pipeline or skill changes in `toolbox/`;
do not customize only the generated root copies. Update ANTONIA with
`./toolbox/update-antonia.sh`; installation and update scripts are maintained
inside the managed toolbox directory.

The default updater follows stable Releases. Use
`./toolbox/update-antonia.sh -dev` to follow the latest development pre-Release
published from ANTONIA's `dev` branch, or add `-version=<tag>` to select an
explicit immutable development version.

Use `/skills` in Codex to browse the installed ANTONIA workflows, or invoke a
Make target skill directly with `$antonia-<command>`. For example,
`$antonia-init-project` runs the managed `make init-project` workflow and
`$antonia-release VERSION_TAG=<version>` runs the guarded release workflow.
See `toolbox/docs/agent-skills.md` for the complete mapping.

The interactive responsibilities are separate: `$antonia-ontologist` creates
or enriches the conceptual model, `$antonia-ontop-mapping` aligns relational
sources with that model, and `$antonia-onto-steward` maintains executable
quality controls. Raw extraction, sampling, and bootstrap evidence belongs
under the configured `TARGET`, never in ontology sources or Releases.

## Local toolchain

Java 17 or later and ROBOT are required. Initial ANTONIA installation invokes
this setup automatically. It can be run again idempotently with:

```bash
make install-robot
```

This installs the pinned ROBOT version and, when necessary, a local Temurin JDK
under `.tools/`. That directory is ignored by Git. `toolbox/common.sh`
automatically prefers `.tools/bin`, so no global `PATH`, package manager, or
`sudo` operation is required. See `toolbox/docs/robot-installation.md` for
verification, configuration, and cleanup instructions.

OntoGPT, Ontop, pySHACL, and PostgreSQL/MySQL clients are installed only when
needed with `make install-semantic-tools`. They are pinned and isolated below
`.tools/`; the base ANTONIA installation does not download them.

GitHub Release imports require the GitHub CLI (`gh`) authenticated with read
access to each repository declared in `config/import.env`.

`make java-conf` generates the ignored machine-specific `config/java.conf`
used to bound processor count and heap through `JAVA_TOOL_OPTIONS`.

Do not commit `.tools/`, `config/java.conf`, downloaded Java runtimes, ROBOT
JARs, the configured `TARGET`, or ad-hoc release packages.

## Build commands

Run commands from the ontology repository root:

- `make import` refreshes configured external ontology Release assets.
- `make install-semantic-tools` installs the local OntoGPT/Ontop/SHACL tools.
- `make generate` expands TSV templates into RDF/XML modules.
- `make reason` runs the source controls selected by `qc/profile.txt` source by
  source before fusion, merges the complete import closure into
  `TARGET/merged.<format>`, and classifies the OWL 2 DL reference ontology into
  `TARGET/classified.<format>`. In a newly initialized project with no ontology
  files yet, it reports the absence of merge inputs and exits successfully
  without creating those outputs.
- `REASONER=hermit make reason` overrides the configured reasoner.
- `make project-ql` derives `TARGET/ontop-ql.<format>` for Ontop from the merged
  ontology without weakening the expressive reference ontology.
- `make report` resolves the non-source SPARQL controls selected by
  `qc/profile.txt` into the canonical post-reasoning ROBOT TSV/HTML report. It
  runs external SHACL validation only when shapes
  exist; use `FAIL_ON=WARN` for ROBOT warnings and `SHACL_FAIL_ON` for SHACL
  severity.
- `make validate` validates the classified reference as OWL 2 DL and the Ontop
  projection as OWL 2 QL.
- `make all` runs generate, reason, QL projection, report, and validation. It
  does not refresh imports or run focused test scripts.
- `make progress` runs the same five targets in the same order, with the same
  overrides and stop-on-error behavior, while displaying progress indicators.
- `make diff OLD=releases/old.<format> NEW=TARGET/classified.<format>` compares ontology
  versions semantically.

`make clean` removes the directory configured by `TARGET`; do not use it when
uncommitted build evidence must be preserved.

## Import-closure contract

`toolbox/reason.sh` must merge with `--collapse-import-closure true` and the
portable XML catalog. A valid `TARGET/merged.<format>` is self-contained: it includes
the configured import closure and has no residual `owl:imports`.

Run `make test-imports` after changing `config/import.env`, the XML catalog, an
ontology import declaration, or merge behavior. Do not replace a raw ontology
URL with a GitHub `/blob/` HTML page. Prefer immutable Release tags for
reproducible builds; use `latest` only when intentionally tracking the newest
published release. Retain download-content validation in `toolbox/import.sh`.

## Modeling and serialization conventions

Use UTF-8 RDF/XML (`.rdf`) for authoritative ontology sources. Generated
outputs use `OUTPUT_FORMAT=rdf|ttl|owl` from `config/config.env`; `rdf` is the
default. Use TSV for templates and SPARQL (`.rq` checks/reports and `.ru`
updates) for validation and transformations. Turtle is acceptable for pinned
external imports and compact test fixtures.

ROBOT does not recognize `.rdf` as an output-format extension. When ROBOT must
write RDF/XML, write an intermediate `.owl` file, copy that byte-equivalent
document to the required `.rdf` delivery name, then remove the intermediate
file. Do not pass a `.rdf` output path directly to ROBOT even with an explicit
format.

Preserve the ontology IRIs configured in `config/config.env`. When enabled in
`qc/profile.txt`, the distributed `example-forbidden_iri` ROBOT rule enforces
unversioned schema IRIs under
`BASE_IRI` and named-individual IRIs under `INSTANCE_BASE_IRI` only in the
project-owned TBox, ABox, generated modules, and annotations. Do not apply this
ownership rule to imported ontologies or the alignment ontology configured by
`MAPPINGS`. Keep generated content template-driven rather than editing files
under `TARGET`. Name project checks descriptively with snake_case and return
exactly `?entity ?property ?value`.

Class equivalence assertions are allowed only in the ontology-to-ontology file
configured by `MAPPINGS`. When `example-forbidden_equivalence` is enabled in
`qc/profile.txt`, `toolbox/reason.sh` validates every other source with ROBOT
before any merge, then uses `asserted-only` for the complete graph so
newly inferred class equivalences remain blocking. Do not declare
`owl:equivalentClass` in the TBox, ABox, imports, generated modules, or
annotations.

The ontology products have distinct content:

- `merged.<format>`: asserted and generated input graph before reasoning;
- `classified.<format>`: expressive OWL 2 DL reference after reasoning;
- `ontop-ql.<format>`: conservative OWL 2 QL projection for Ontop.

The release may retain `<name>.owl` as a compatibility reserialization of the
same base `TBOX` graph as `<name>.<format>`; it is not another semantic product.

## Testing and validation

Before proposing ontology or pipeline changes, run:

```bash
make import
make test-imports
make all
make test-profiles
make test-equivalences
```

A successful change leaves the import closure self-contained, all ROBOT report
queries empty, QC acceptable, and both OWL profile validations clean. Inspect
the canonical QC report and optional SHACL reports under `TARGET` on failure. Add
focused fixtures under `tests/data/`, shell
tests under `tests/robot/`, and SPARQL contracts under `tests/sparql/`.

If Java or ROBOT is unavailable, run `make install-robot`; do not report full
validation as successful when only shell, XML, or dry-run checks ran.

## Release contract

Run `make all` and the focused tests before `make release`. The ontology release
script packages existing artifacts and does not rebuild them. A release may
contain:

- the configured base ontology `TBOX` as `<name>.<format>` and, when needed,
  its retained `<name>.owl` compatibility copy;
- `<name>-merged.<format>`;
- `<name>-ql.<format>`;
- every RDF/Turtle mapping in `MAPPINGS_DIR`, byte-for-byte with a `mapping-`
  Release prefix;
- every RDF/Turtle service catalog in `SERVICES_DIR`, byte-for-byte with a
  `service-` Release prefix and outside the merged/classified ontology;
- `<name>.obda` when the configured source exists;
- available QC, profile-validation, and diff reports.

Do not release datasource or service connection `.properties` files. Release
enumeration is limited to direct `.rdf`/`.ttl` files in `MAPPINGS_DIR` and
`SERVICES_DIR`; preserve an existing `mapping-` or `service-` prefix and add it
to the Release filename only when absent. The release
script performs Git commits, branch/tag operations, pushes, and optional GitHub
Release creation; do not invoke it merely to test packaging.

## Commits and pull requests

Preserve unrelated working-tree changes. Use short imperative commit subjects,
keep each commit scoped to one modeling or pipeline concern, and do not commit
accidental build outputs. Pull requests should explain semantic impact, list
the exact validation commands run, link the relevant issue, and include report
or ontology-diff excerpts when output semantics change.
