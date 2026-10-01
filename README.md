# Ontology Toolbox

This repository provides a ROBOT-based toolchain for maintaining expressive
OWL 2 DL reference ontologies and operational Ontop projections.

It is designed to be used as a **Git submodule** named `toolbox/` inside a
host repository that contains the actual ontology content.

## Architecture

- The authoritative ontology is maintained in RDF/XML under `src/edit/`.
- `tmp/classified.rdf` is the reasoned OWL 2 DL reference ontology.
- `tmp/merged.rdf` is the assembled graph before reasoning.
- `tmp/ontop-ql.rdf` is the OWL 2 QL projection for Ontop.
- Releases keep both `<name>.rdf` and its `<name>.owl` compatibility copy.
- An OBDA mapping is released when present; datasource `.properties` files are
  never packaged.

See [the architecture](docs/architecture.md) and
[the release process](docs/release-process.md) for the content boundaries.

## Quick start (host repository)

Add this repository as a submodule and initialize the project structure:

```bash
# Add as submodule named 'toolbox'
git submodule add <this-repo-url> toolbox
git submodule update --init --recursive

# Initialize the host repository structure
make init-project

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

`make install-robot` installs ROBOT and, when needed, Java 17 under the
Git-ignored `.tools/` directory. See
[the local installation procedure](docs/robot-installation.md).
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
operations; review [the release process](docs/release-process.md) first.
