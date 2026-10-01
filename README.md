# Ontology Toolbox

This repository provides a ROBOT-based toolchain for maintaining expressive
OWL 2 DL reference ontologies and operational Ontop projections.

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

See [the architecture](toolbox/docs/architecture.md) and
[the release process](toolbox/docs/release-process.md) for the content
boundaries.

## Quick start (host repository)

Copy only `install-antonia.sh` to the root of the host Git repository, then
initialize the project structure:

```bash
# Download the latest released toolbox and initialize the host project
./install-antonia.sh

# Install the repository-local toolchain
make install-robot

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
root. It also copies `toolbox/AGENTS.md` to the ontology root. This keeps the
usual `make <target>` commands and ontology-agent instructions while their
authoritative versions remain part of the versioned toolbox. The bootstrap
`install-antonia.sh` at the ontology root is deleted after successful
initialization; maintained installation and update scripts remain under
`toolbox/`.

To update only the managed toolbox files to the latest release:

```bash
./toolbox/update-antonia.sh
```

During an update, ANTONIA compares each project `.env` file with the template
shipped in the new Release. It reports variables that already exist, variables
introduced by the Release, and variables that are no longer expected. Only new
assignments are appended with their default value; existing and obsolete
assignments are preserved unchanged. The root ontology `Makefile` and
`AGENTS.md` are replaced by the corresponding files supplied by the new
Release.

Set `ANTONIA_VERSION=<tag>` on either command to install a specific immutable
release. Each downloaded archive is checked against its published SHA-256
checksum. Updates refuse to replace a `toolbox/` directory that does not carry
the ANTONIA management marker.

`make install-robot` installs ROBOT and, when needed, Java 17 under the
Git-ignored `.tools/` directory. See the
[local installation procedure](toolbox/docs/robot-installation.md).
GitHub Release imports also require an authenticated GitHub CLI (`gh`) with
read access to each configured repository.

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
