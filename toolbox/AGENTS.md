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
`robot query` gates. Transient build artifacts belong in `tmp/`; distributable
current and dated packages belong in `releases/`.

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
under `tmp/`, never in ontology sources or Releases.

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
JARs, `tmp/`, or ad-hoc release packages.

## Build commands

Run commands from the ontology repository root:

- `make import` refreshes configured external ontology Release assets.
- `make install-semantic-tools` installs the local OntoGPT/Ontop/SHACL tools.
- `make generate` expands TSV templates into RDF/XML modules.
- `make reason` merges the complete import closure into `tmp/merged.<format>` and
  classifies the OWL 2 DL reference ontology into `tmp/classified.<format>`. In a
  newly initialized project with no ontology files yet, it reports the absence
  of merge inputs and exits successfully without creating those outputs.
- `REASONER=hermit make reason` overrides the configured reasoner.
- `make project-ql` derives `tmp/ontop-ql.<format>` for Ontop from the merged
  ontology without weakening the expressive reference ontology.
- `make report` injects native and project SPARQL controls into the canonical
  ROBOT TSV/HTML report. It runs external SHACL validation only when shapes
  exist; use `FAIL_ON=WARN` for ROBOT warnings and `SHACL_FAIL_ON` for SHACL
  severity.
- `make validate` validates the classified reference as OWL 2 DL and the Ontop
  projection as OWL 2 QL.
- `make all` runs generate, reason, QL projection, report, and validation. It
  does not refresh imports or run focused test scripts.
- `make progress` runs the same five targets in the same order, with the same
  overrides and stop-on-error behavior, while displaying progress indicators.
- `make diff OLD=releases/old.<format> NEW=tmp/classified.<format>` compares ontology
  versions semantically.

`make clean` removes `tmp/`; do not use it when uncommitted build evidence must
be preserved.

## Import-closure contract

`toolbox/reason.sh` must merge with `--collapse-import-closure true` and the
portable XML catalog. A valid `tmp/merged.<format>` is self-contained: it includes
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

Preserve the ontology IRIs configured in `config/config.env`. The native
`forbidden_iri` ROBOT rule enforces unversioned schema IRIs under `BASE_IRI` and
named-individual IRIs under `INSTANCE_BASE_IRI`. Keep generated content
template-driven rather than editing files in `tmp/`. Name project checks
descriptively with snake_case and return exactly
`?entity ?property ?value`.

The ontology products have distinct content:

- `merged.<format>`: asserted and generated input graph before reasoning;
- `classified.<format>`: expressive OWL 2 DL reference after reasoning;
- `ontop-ql.<format>`: conservative OWL 2 QL projection for Ontop.

The release may retain `<name>.owl` as a compatibility reserialization of the
same classified graph as `<name>.<format>`; it is not another semantic product.

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
the canonical QC report and optional SHACL reports under `tmp/` on failure. Add
focused fixtures under `tests/data/`, shell
tests under `tests/robot/`, and SPARQL contracts under `tests/sparql/`.

If Java or ROBOT is unavailable, run `make install-robot`; do not report full
validation as successful when only shell, XML, or dry-run checks ran.

## Release contract

Run `make all` and the focused tests before `make release`. The ontology release
script packages existing artifacts and does not rebuild them. A release may
contain:

- `<name>.<format>` and, when needed, its retained `<name>.owl` compatibility copy;
- `<name>-merged.<format>`;
- `<name>-ql.<format>`;
- the configured RDF mapping ontology, byte-for-byte, when present;
- `<name>.obda` when the configured source exists;
- available QC, profile-validation, and diff reports.

Do not release datasource `.properties` files. The release
script performs Git commits, branch/tag operations, pushes, and optional GitHub
Release creation; do not invoke it merely to test packaging.

## Commits and pull requests

Preserve unrelated working-tree changes. Use short imperative commit subjects,
keep each commit scoped to one modeling or pipeline concern, and do not commit
accidental build outputs. Pull requests should explain semantic impact, list
the exact validation commands run, link the relevant issue, and include report
or ontology-diff excerpts when output semantics change.
