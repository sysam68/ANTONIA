# Repository Guidelines

## Project structure

This repository builds the Industry Model Directory (IMD) ontology with ROBOT.
The authoritative schema is `src/edit/imd-tbox.rdf`; the optional ABox is
`src/edit/ontology-abox.rdf`; an optional ontology mapping is configured through
`MAPPINGS`; Ontop mappings are held in `src/edit/imd-tbox.obda`. Never package
datasource `.properties` files.

External dependencies are selected in `config/import.env` as GitHub Release
assets, downloaded into `src/edit/imports/`, and resolved through
`src/edit/catalog-v001.xml`. Selectors may be immutable release tags or
`latest`; the latter is resolved to a concrete tag and reported during import.
The BIAN import is already merged with its transitive ArchiMate and SKOS
content. Treat these imported ontology files as versioned source dependencies,
not as build outputs.

Keep generated ontology modules in `src/edit/modules/`, SHACL constraints in
`src/shapes/`, and SPARQL checks, reports, and updates under `src/sparql/`.
Transient build artifacts belong in `tmp/`; distributable current and dated
packages belong in `releases/`.

## Local toolchain

Java 17 or later and ROBOT are required. The recommended setup is:

```bash
make install-robot
```

This installs the pinned ROBOT version and, when necessary, a local Temurin JDK
under `.tools/`. That directory is ignored by Git. `toolbox/common.sh`
automatically prefers `.tools/bin`, so no global `PATH`, package manager, or
`sudo` operation is required. See `docs/robot-installation.md` for verification,
configuration, and cleanup instructions.

GitHub Release imports require the GitHub CLI (`gh`) authenticated with read
access to each repository declared in `config/import.env`.

`make java-conf` can generate a machine-specific `conf/java.conf` that bounds
the processor count and heap used through `JAVA_TOOL_OPTIONS`. The file is
ignored by Git; the generator `toolbox/java_conf.sh` remains tracked.

Do not commit `.tools/`, `conf/java.conf`, downloaded Java runtimes, ROBOT JARs,
`tmp/`, or ad-hoc release packages.

## Build commands

Run commands from the repository root:

- `make import` refreshes the configured external ontology Release asset.
- `make generate` expands TSV templates into RDF/XML modules.
- `make reason` merges the complete import closure into `tmp/merged.rdf` and
  classifies the OWL 2 DL reference ontology into `tmp/classified.rdf`.
- `REASONER=hermit make reason` overrides the configured reasoner.
- `make project-ql` derives `tmp/ontop-ql.rdf` for Ontop from the merged
  ontology; it does not weaken the expressive DL reference ontology.
- `make report` runs QC reports and blocking SPARQL checks; use
  `FAIL_ON=WARN make report` when warnings must fail.
- `make validate` validates the classified reference as OWL 2 DL and the Ontop
  projection as OWL 2 QL.
- `make all` runs generate, reason, QL projection, report, and validation. It
  does not refresh imports or run the focused test scripts.
- `make progress` invokes the same five Make targets, in the same order and
  with the same environment overrides and stop-on-error behavior as `make all`,
  while displaying progress indicators.
- `make diff OLD=releases/imd.rdf NEW=tmp/classified.rdf` compares ontology
  versions semantically.

`make clean` removes `tmp/`; do not use it when uncommitted build evidence
must be preserved.

## Import-closure contract

`toolbox/reason.sh` must merge with `--collapse-import-closure true` and the
portable XML catalog. A valid `tmp/merged.rdf` is self-contained: it includes
IMD, BIAN, ArchiMate, and SKOS axioms and has no residual `owl:imports`.

Run `make test-imports` after changing `config/import.env`, the XML catalog, an
ontology import declaration, or merge behavior. Do not replace a raw ontology
URL with a GitHub `/blob/` HTML page. Prefer an immutable Release tag for
reproducible builds; use `latest` only when intentionally tracking the newest
published release. Retain the download-content validation in
`toolbox/import.sh`.

## Modeling and serialization conventions

Use UTF-8 RDF/XML (`.rdf`) for authoritative ontology sources and generated
outputs, TSV for templates, and SPARQL (`.rq` checks/reports and `.ru` updates)
for validation and transformations. Turtle is acceptable for pinned external
imports and compact test fixtures.

ROBOT does not recognize `.rdf` as an output-format extension. When ROBOT must
write RDF/XML, scripts must write an intermediate `.owl` file, copy that
byte-equivalent RDF/XML document to the required `.rdf` delivery name, then
remove the intermediate file. Do not pass a `.rdf` output path directly to
ROBOT, even when specifying an explicit format.

Preserve the configured IMD IRIs from `config/config.env`. Keep generated
content template-driven rather than editing files in `tmp/`. Name checks
descriptively with snake_case, for example `missing_labels.rq`.

The ontology products have distinct content:

- `merged.rdf`: asserted and generated input graph before reasoning;
- `classified.rdf`: expressive OWL 2 DL reference after reasoning;
- `ontop-ql.rdf`: conservative OWL 2 QL projection for Ontop.

The release also retains `<name>.owl`, a compatibility reserialization of the
same classified graph as `<name>.rdf`; it is not a fourth semantic product.

## Testing and validation

Before proposing ontology or pipeline changes, run:

```bash
make import
make test-imports
make all
make test-profiles
make test-equivalences
```

A successful change leaves the import closure self-contained, blocking SPARQL
checks empty, QC acceptable, and both OWL profile validations clean. Inspect
reports under `tmp/` on failure. Add focused fixtures under `tests/data/`,
shell tests under `tests/robot/`, and SPARQL contracts under `tests/sparql/`.
The focused individual-equivalence tests use the OWL 2 DL HermiT reasoner by
default on the IMD TBox without its external import declaration; import closure
is tested separately. Set `TEST_REASONER` only to compare another reasoner.

If Java or ROBOT is unavailable, run `make install-robot`; do not report full
validation as successful when only shell, XML, or dry-run checks were executed.

## Release contract

Run `make all` and the focused tests before `make release`. The release script
packages existing artifacts and does not rebuild them. A release contains:

- `<name>.rdf` and its retained `<name>.owl` compatibility copy;
- `<name>-merged.rdf`;
- `<name>-ql.rdf`;
- the configured RDF mapping ontology, byte-for-byte, when present;
- `<name>.obda` when the configured source exists;
- available QC, profile-validation, and diff reports.

Do not release Turtle files or datasource `.properties` files. The release
script performs Git commits, branch/tag operations, pushes, and optional GitHub
release creation; do not invoke it merely to test packaging.

## Commits and pull requests

Preserve unrelated working-tree changes. Use short imperative commit subjects,
keep each commit scoped to one modeling or pipeline concern, and do not commit
accidental build outputs. Pull requests should explain semantic impact, list
the exact validation commands run, link the relevant issue, and include report
or ontology-diff excerpts when output semantics change.
