# ANTONIA — Ontology Toolbox

ANTONIA is a reusable ROBOT-based toolbox for maintaining expressive OWL 2 DL
reference ontologies and operational Ontop projections. It combines a
repeatable ontology build pipeline with interactive skills for ontology
authoring, OBDA mapping, and executable quality controls.

It is distributed as a versioned GitHub Release asset installed under
`toolbox/` inside a host repository. The managed directory contains only the
runtime scripts and their documentation; it is not a Git submodule.

## Architecture

- The authoritative ontology is maintained in RDF/XML under `src/edit/`.
- `tmp/classified.rdf` is the reasoned OWL 2 DL reference ontology.
- `tmp/merged.rdf` is the assembled graph before reasoning.
- `tmp/ontop-ql.rdf` is the OWL 2 QL projection for Ontop.
- Releases keep both `<name>.rdf` and its `<name>.owl` compatibility copy.
- An OBDA mapping is released when present; datasource `.properties` files are
  never packaged.
- Interactive skills derive reviewed ontology candidates from documents or
  PostgreSQL/MySQL metadata, align Ontop mappings, and author SHACL/SPARQL gates.

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
by ANTONIA. This keeps the usual
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
and keep raw evidence under `tmp/`. See
[semantic authoring](toolbox/docs/semantic-authoring.md).

To update only the managed toolbox files to the latest release:

```bash
./toolbox/update-antonia.sh
```

During an update, ANTONIA compares each project `.env` file with the template
shipped in the new Release. It reports variables that already exist, variables
introduced by the Release, and variables that are no longer expected. Only new
assignments are appended with their default value; existing and obsolete
assignments are preserved unchanged. The root ontology `Makefile`, `AGENTS.md`,
and ANTONIA-managed skills are replaced by the corresponding files supplied by
the new Release.

Set `ANTONIA_VERSION=<tag>` on either command to install a specific immutable
release. Each downloaded archive is checked against its published SHA-256
checksum. Updates refuse to replace a `toolbox/` directory that does not carry
the ANTONIA management marker.

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
| `$antonia-onto-steward` | Define executable ontology and graph quality gates | SHACL shapes, ROBOT rules, and blocking SPARQL checks |

Each skill first establishes the scope with the user. It requires a clean Git
worktree, uses a dedicated branch, presents the resulting diff, and leaves the
changes uncommitted. Raw documents, metadata, samples, extractions, and Ontop
bootstrap outputs remain in the ignored `tmp/` directory.

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

`$antonia-onto-steward` turns reviewed requirements into SHACL shapes, ROBOT
rules, or blocking SPARQL checks. Every control should have a stable identifier,
rationale, target, severity, message, and positive and negative examples.

`make report` evaluates SHACL against the classified graph and writes:

- `tmp/shacl_report.ttl`, the machine-readable validation report;
- `tmp/shacl_report.txt`, the human-readable validation report.

The default `SHACL_FAIL_ON=VIOLATION` makes a SHACL violation fail the report.
`WARNING`, `INFO`, and `NONE` provide alternative thresholds. Existing ROBOT
and SPARQL gates continue to run in the same report workflow.

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

ANTONIA maintainers publish the toolbox with:

```bash
make test
make package VERSION=v1.0.0
make release VERSION=v1.0.0
```

The command requires a clean `main` synchronized with `origin/main`. It builds
and uploads the stable assets `antonia-toolbox.tar.gz` and
`antonia-toolbox.tar.gz.sha256`; installers resolve these assets through the
latest GitHub Release or through the tag selected by `ANTONIA_VERSION`.
