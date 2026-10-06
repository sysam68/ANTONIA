# AntOnIA — Ontology Toolbox

AntOnIA is a reusable ROBOT-based toolbox for maintaining expressive OWL 2 DL
reference ontologies and operational Ontop projections. It combines a
repeatable ontology build pipeline with interactive skills for ontology
authoring, OBDA mapping, and executable quality controls.

It is distributed as a versioned GitHub Release asset installed under
`toolbox/` inside a host repository. The managed directory contains only the
runtime scripts and their documentation; it is not a Git submodule.

## Architecture

- The authoritative ontology is maintained in RDF/XML under `src/edit/`.
- `OUTPUT_FORMAT=rdf|ttl|owl` controls every generated ontology serialization.
- `TARGET/classified.<format>` is the reasoned OWL 2 DL reference ontology.
- `TARGET/merged.<format>` is the assembled graph before reasoning.
- `TARGET/ontop-ql.<format>` is the OWL 2 QL projection for Ontop.

`TARGET` is configured in `config/config.env` and defaults to `tmp/`.
- Releases use `<name>.<format>` and retain an `.owl` compatibility copy when
  the configured primary format is not already `owl`.
- An OBDA mapping is released when present; datasource `.properties` files are
  never packaged.
- Class equivalence assertions are accepted only from the RDF ontology mapping
  configured by `MAPPINGS`; all other sources are checked before fusion.
- Interactive skills derive reviewed ontology candidates from documents or
  PostgreSQL/MySQL metadata, align Ontop mappings, and author ROBOT-integrated
  controls or optional SHACL shapes.

See [the architecture](toolbox/docs/architecture.md) and
[the release process](toolbox/docs/release-process.md) for the content
boundaries.

## Quick start (host repository)

Copy only `install-antonia.sh` to the root of the host Git repository, then
initialize the project structure:

```bash
# Download the latest released toolbox and initialize the host project
./install-antonia.sh

# Configure your ontology
# Edit config/config.env and src/edit/myOntology-tbox.rdf

# Run the pipeline
make import
make test-imports
make all
make test-profiles
make test-equivalences
```

Installation copies the released `toolbox/Makefile` to the ontology repository
root. It also copies `toolbox/AGENTS.md` to the ontology root and synchronizes
the skills declared by `toolbox/.agents/.antonia-managed` into the root
`.agents/skills/` directory. ANTONIA replaces only its declared skills during
updates and preserves unrelated project skills. Installation refuses to
overwrite an existing homonymous skill that is not already marked as managed
by ANTONIA. Installation also copies the distributed ROBOT controls from
`toolbox/checks/` into the path configured by `SPARQL_CHECKS`. This keeps the usual
`make <target>` commands, ontology-agent instructions, and Codex workflows while
their authoritative versions remain part of the versioned toolbox. Existing
`.gitignore` content is preserved, while missing `tmp/` and `.tools/` rules are
appended. The bootstrap
`install-antonia.sh` at the ontology root installs the repository-local ROBOT
toolchain through `toolbox/install_robot.sh`, then deletes itself only after
the project initialization and toolchain installation both succeed. Maintained
installation and update scripts remain under `toolbox/`.

In Codex CLI or the IDE, use `/skills` to browse the installed ANTONIA commands
or invoke one directly, for example `$antonia-init-project`,
`$antonia-reason REASONER=hermit`, or
`$antonia-release VERSION_TAG=2026-10-01`. Repository skills cannot define new
top-level `/antonia-*` slash commands; the supported distributed form is
`$antonia-*`. See [the complete skill mapping](toolbox/docs/agent-skills.md).

The semantic-authoring workflows are `$antonia-ontologist`,
`$antonia-ontop-mapping`, and `$antonia-onto-steward`. They require a clean
worktree, work on a dedicated branch, leave the result uncommitted for review,
and keep raw evidence under the configured `TARGET`. See
[semantic authoring](toolbox/docs/semantic-authoring.md).

To update only the managed toolbox files to the latest release:

```bash
./toolbox/update-antonia.sh
```

The stable channel follows the latest non-prerelease published from `main`.
Development builds are explicit:

```bash
# Latest pre-Release published from dev
./toolbox/update-antonia.sh -dev

# A specific pre-Release tag
./toolbox/update-antonia.sh -dev -version=v1.5.0-dev.1
```

Resolving the latest development pre-Release requires an authenticated GitHub
CLI (`gh`). Selecting a known tag with `-version=<tag>` downloads that immutable
Release directly and does not require discovery.

During an update, ANTONIA compares each project `.env` file with the template
shipped in the new Release. It reports variables that already exist, variables
introduced by the Release, and variables that are no longer expected. Only new
assignments are appended with their default value; existing and obsolete
assignments are preserved unchanged. The root ontology `Makefile`, `AGENTS.md`,
and ANTONIA-managed skills are replaced by the corresponding files supplied by
the new Release. Distributed controls are refreshed in `SPARQL_CHECKS` while
unrelated project controls are preserved.

For stable-channel installation or update, set `ANTONIA_VERSION=<tag>` to use a
specific immutable Release. For the development channel, prefer the explicit
`-dev -version=<tag>` syntax. Each downloaded archive is checked against its
published SHA-256 checksum. Updates refuse to replace a `toolbox/` directory
that does not carry the ANTONIA management marker.

The initial installation automatically installs ROBOT and, when needed, Java
17 under the Git-ignored `.tools/` directory. The idempotent
`make install-robot` target remains available to verify or repair this local
toolchain. See the
[local installation procedure](toolbox/docs/robot-installation.md).
GitHub Release imports also require an authenticated GitHub CLI (`gh`) with
read access to each configured repository.

## Interactive semantic authoring

OntoGPT, Ontop, pySHACL, and JDBC support are installed on demand before
starting one of the semantic workflows:

```bash
make install-semantic-tools
```

The command uses pinned, checksum-verified binaries and a repository-local
Python environment under `.tools/`. It makes no global package changes.

Then invoke the required skill from Codex:

| Skill | Purpose | Main result |
| --- | --- | --- |
| `$antonia-ontologist` | Create or enrich an ontology from documents or an authorized PostgreSQL/MySQL source | Reviewed RDF/XML TBox and ontology design record |
| `$antonia-ontop-mapping` | Align a relational schema with the existing ontology | Validated OBDA mapping |
| `$antonia-onto-steward` | Define executable ontology and graph quality gates | ROBOT-integrated rules and optional SHACL shapes |

Each skill first establishes the scope with the user. It requires a clean Git
worktree, uses a dedicated branch, presents the resulting diff, and leaves the
changes uncommitted. Raw documents, metadata, samples, extractions, and Ontop
bootstrap outputs remain under the configured `TARGET` directory.

### Ontology creation and enrichment

`$antonia-ontologist` accepts UTF-8 text, Markdown, text-based PDF, DOCX,
PostgreSQL, and MySQL sources. For documents, OntoGPT extracts structured
candidates with a domain-neutral LinkML template. For databases, Ontop extracts
schema metadata and ANTONIA can read a bounded sample from explicitly
allowlisted tables.

OntoGPT is not the ontology authority: its output is evidence to review.
ANTONIA remains responsible for distinguishing classes, individuals, and
properties; resolving identity and IRI decisions; recording uncertainty; and
transforming accepted candidates into the business ontology.

Configure the workflow in `config/config.env`:

```dotenv
ONTOGPT_MODEL=ollama/<local-model>       # or another LiteLLM model
ONTOGPT_ALLOW_EXTERNAL_LLM=0            # set to 1 only after explicit review
DB_SAMPLE_TABLES=public.customer         # explicit comma-separated allowlist
DB_SAMPLE_ROWS=20                        # accepted range: 1..100
DB_SAMPLE_TO_LLM=0                       # independent consent for sample values
ONTOLOGY_DESIGN_RECORD=docs/ontology-design.md
```

A non-local model cannot receive source content unless
`ONTOGPT_ALLOW_EXTERNAL_LLM=1`. Database values require the additional
`DB_SAMPLE_TO_LLM=1` authorization. The presence of an API key never implies
either consent.

### Ontop mapping

`$antonia-ontop-mapping` uses the file configured by `ONTOP_PROPERTIES` to
extract relational metadata and create a temporary Ontop bootstrap. The
bootstrap is only technical evidence: it is not merged into the authoritative
ontology. The skill confirms primary keys, instance IRI templates, joins,
nullable columns, datatypes, and target ontology terms before updating and
validating the configured `OBDA` file.

Copy the generated example and keep credentials local:

```bash
cp src/edit/myOntology.properties.example src/edit/myOntology.properties
```

Real `src/edit/*.properties` files are Git-ignored and excluded from ANTONIA
packages and ontology Releases. Do not put API keys or database credentials in
`config.env`, an OBDA file, or an ontology design record.

### Stewardship and quality gates

`$antonia-onto-steward` turns reviewed requirements into ROBOT rules or, only
when shape semantics are required, SHACL shapes. Project SPARQL controls must
return exactly `?entity ?property ?value`; `make report` renders the controls
whose file-base names are enabled in `qc/profile.txt` and injects them into the
canonical ROBOT profile.
Every control should have a stable identifier, rationale, target, severity,
message, and positive and negative examples.

When SHACL shapes exist, `make report` evaluates them against the classified
graph and writes:

- `TARGET/shacl_report.ttl`, the machine-readable validation report;
- `TARGET/shacl_report.txt`, the human-readable validation report.

The default `SHACL_FAIL_ON=VIOLATION` makes a SHACL violation fail the report.
`WARNING`, `INFO`, and `NONE` provide alternative thresholds. pySHACL is not
invoked when no shape exists. Project SPARQL controls appear in the canonical
ROBOT TSV/HTML report. Native source-scope controls run through `robot report`
before merge so a failure identifies the responsible source file.

ANTONIA distributes the `example-forbidden_iri` ROBOT control. When its profile
entry uses the `project-source` scope, it renders
`BASE_IRI` and `INSTANCE_BASE_IRI` from `config/config.env` before any merge
and applies them only to project-owned ontology sources: TBox, ABox, generated
modules, and annotations. Imported ontologies and the alignment ontology
configured by `MAPPINGS` retain their publishers' namespaces and are excluded
from this ownership rule. The rule rejects versioned schema IRIs and keeps
ontology-entity and named-individual namespaces separate.

When its profile entry uses the `non-mapping-source` scope, the distributed
`example-forbidden_equivalence` control runs through `robot report` on every ontology
source before fusion, except the RDF alignment ontology configured by
`MAPPINGS`. The complete graph then uses ROBOT's `asserted-only` reasoning
policy: asserted mapping equivalences are accepted, while newly inferred class
equivalences remain blocking.

### V1 boundaries

V1 does not provide Neo4j ingestion, OCR for scanned documents, complete
relational materialization for SHACL, remote URL ingestion, or automatic
commit, push, merge, Release publication, or ontology acceptance. See the
[complete semantic-authoring contract](toolbox/docs/semantic-authoring.md).

The import manifest selects a GitHub Release asset by an explicit release tag
or by `latest`. The import contract checks that the downloaded artifact
contains the expected ontology content and has no residual `owl:imports`.
The complete build then generates RDF/XML modules, merges and classifies the DL
ontology, derives the QL projection, runs quality checks, and validates both
OWL profiles.

To create a release from fresh, committed build artifacts:

```bash
make release
```

The release command performs Git branch, tag, and optional GitHub release
operations; review the
[release process](toolbox/docs/release-process.md) first.

## Publishing ANTONIA

ANTONIA maintainers publish stable Releases from a clean `main` synchronized
with `origin/main`:

```bash
make test
make package VERSION=v1.0.0
make release VERSION=v1.0.0
```

Development pre-Releases use a clean `dev` synchronized with `origin/dev`:

```bash
make test
make prerelease VERSION=v1.1.0-dev.1
```

Both commands build and upload the assets `antonia-toolbox.tar.gz` and
`antonia-toolbox.tar.gz.sha256`; installers resolve these assets through the
stable channel, the development pre-Release channel, or an explicitly selected
tag. A pre-Release is marked as such on GitHub and is never promoted to
`latest`.
