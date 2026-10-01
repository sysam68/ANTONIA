# ANTONIA Repository Guidelines

## Repository purpose

This repository develops and publishes ANTONIA, a reusable ROBOT-based ontology
toolbox. It is not an ontology project itself. Ontology sources, imported
ontologies, generated reasoning outputs, and ontology release packages do not
belong in this repository.

ANTONIA is distributed as the GitHub Release asset
`antonia-toolbox.tar.gz`, accompanied by
`antonia-toolbox.tar.gz.sha256`. The archive must contain exactly one
top-level `toolbox/` directory.

## Responsibility split

The two root-level governance files apply only to ANTONIA development:

- `Makefile` runs ANTONIA checks, tests, packaging, and publication;
- `AGENTS.md` defines how ANTONIA itself is maintained.

The two files under `toolbox/` are part of the distributed product:

- `toolbox/Makefile` runs ontology build, validation, and release processes;
- `toolbox/AGENTS.md` defines how an ontology repository is maintained.

During installation and update, the distributed `toolbox/Makefile` and
`toolbox/AGENTS.md` are copied to the ontology repository root. Do not put
ANTONIA-maintenance targets or instructions in those distributed files.

## Source structure

- `toolbox/*.sh` contains the runtime scripts distributed to ontology projects.
- `toolbox/Makefile` is the authoritative ontology-project Makefile.
- `toolbox/AGENTS.md` is the authoritative ontology-project agent guidance.
- `toolbox/templates/config/` contains the expected project configuration.
- `toolbox/docs/` contains documentation shipped with the toolbox.
- `install-antonia.sh` installs a released toolbox and initializes a project.
- `update-antonia.sh` is the source of the updater packaged under `toolbox/`.
- `package-antonia.sh` builds the Release archive and checksum.
- `release-antonia.sh` tags and publishes a GitHub Release.
- `tests/` contains ANTONIA-specific fixtures and regression tests.
- `dist/` contains ignored local packaging outputs.

Do not restore historical ontology content, generated `target/` or `tmp/`
trees, ontology-specific mappings, or old ontology releases to this repository.

## Distribution contract

The package allowlist in `package-antonia.sh` is authoritative. A valid archive
must include at least:

- `toolbox/Makefile` and `toolbox/AGENTS.md`;
- every runtime shell script required by the ontology pipeline;
- `toolbox/templates/config/config.env`;
- toolbox documentation;
- `.antonia-managed`, recording the concrete Release version.

Never package datasource `.properties` files, local Java installations,
downloaded ROBOT JARs, ontology build outputs, or repository-local secrets.

Installation and update must:

- download a concrete or latest public GitHub Release asset;
- verify its published SHA-256 checksum before extraction;
- reject unexpected archive paths and symbolic links;
- refuse to update a `toolbox/` directory without `.antonia-managed`;
- avoid a nested `toolbox/toolbox/` layout;
- replace only the managed toolbox directory;
- copy the released Makefile and AGENTS.md to the ontology root;
- package installation and update scripts inside `toolbox/`;
- remove the root bootstrap installer only after successful initialization;
- preserve existing configuration values and obsolete variables;
- append only configuration variables introduced by the new Release.

## Development commands

Run commands from the ANTONIA repository root:

```bash
make check
make test
make package VERSION=v1.0.0
make release VERSION=v1.0.0
```

`make check` validates shell syntax and required distribution files.
`make test` adds configuration-migration and archive-structure tests.
`make package` creates local ignored assets without publishing them.
`make release` is an external publication operation: it requires a clean
`main` branch exactly synchronized with `origin/main`, creates the tag, pushes
it, and creates the GitHub Release.

Do not invoke `make release` merely to test packaging. Never bypass the clean
worktree or synchronized-main guards: the published archive must correspond
exactly to the tagged commit.

## Compatibility and testing

Runtime scripts must remain compatible with macOS Bash 3.2 unless a newer Bash
requirement is explicitly adopted and documented. Prefer portable shell
constructs and support both `shasum -a 256` and `sha256sum`.

After changing installation, update, packaging, configuration migration,
`toolbox/Makefile`, or `toolbox/AGENTS.md`, run:

```bash
make check
make test
```

Also exercise installation and update in a temporary Git repository when the
archive layout or root-file synchronization changes. Verify that:

- the archive has one `toolbox/` root;
- installation creates root `Makefile` and `AGENTS.md` copies;
- update replaces both root copies;
- project configuration remains byte-for-byte unchanged before appended new
  assignments;
- a second update is idempotent.

Do not report publication success unless the remote tag, GitHub Release, both
assets, and their checksum have been verified.

## Commits and pull requests

Preserve unrelated working-tree changes. Use short imperative commit subjects
and keep packaging, runtime, and documentation changes coherent. Pull requests
must explain changes to the distribution contract, list exact validation
commands, and call out any compatibility impact for existing ontology projects.
