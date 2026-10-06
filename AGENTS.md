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
- `toolbox/*.py` contains deterministic semantic-authoring and validation helpers.
- `toolbox/Makefile` is the authoritative ontology-project Makefile.
- `toolbox/AGENTS.md` is the authoritative ontology-project agent guidance.
- `toolbox/.agents/` contains the repository skills installed into ontology
  projects, including one guarded skill for every target defined by the
  ontology-project Makefile.
- `toolbox/templates/config/` contains the expected project configuration.
- `toolbox/checks/` contains every ROBOT control example distributed by
  ANTONIA. These are examples, not an activation list: every control filename
  in this ANTONIA development repository must start with `example-`.
- `toolbox/docs/` contains documentation shipped with the toolbox.
- `install-antonia.sh` installs a released toolbox and initializes a project.
- `update-antonia.sh` is the source of the updater packaged under `toolbox/`.
- `package-antonia.sh` builds the Release archive and checksum.
- `release-antonia.sh` tags and publishes a stable GitHub Release from `main`
  or a development pre-Release from `dev`.
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
- every `toolbox/checks/example-*.rq` control example, with its filename
  unchanged;
- toolbox documentation;
- `toolbox/.agents/.antonia-managed` and every declared repository skill;
- `.antonia-managed`, recording the concrete Release version.

Never package datasource `.properties` files, local Java installations,
downloaded ROBOT JARs, ontology build outputs, or repository-local secrets.

The optional semantic-authoring toolchain is installed on demand below
`.tools/` by `make install-semantic-tools`. Its downloaded Python, OntoGPT,
Ontop, pySHACL, and JDBC components are runtime dependencies and must never be
included in the ANTONIA Release archive.

Installation and update must:

- download a concrete or latest public GitHub Release asset;
- verify its published SHA-256 checksum before extraction;
- reject unexpected archive paths and symbolic links;
- refuse to update a `toolbox/` directory without `.antonia-managed`;
- avoid a nested `toolbox/toolbox/` layout;
- replace only the managed toolbox directory;
- copy the released Makefile and AGENTS.md to the ontology root;
- synchronize ANTONIA-managed skills into the ontology root `.agents/skills/`
  while preserving unrelated project skills;
- copy every file from `toolbox/checks/` into the ontology project's configured
  ROBOT-control directory, preserving each `example-*` filename exactly during
  both installation and update;
- refuse to overwrite a homonymous root skill unless the installed ANTONIA
  manifest already declares it as managed;
- add missing `tmp/` and `.tools/` exclusions without replacing the host
  `.gitignore`;
- package installation and update scripts inside `toolbox/`;
- install the repository-local ROBOT toolchain during initial installation;
- remove the root bootstrap installer only after successful initialization and
  ROBOT installation;
- preserve existing configuration values and obsolete variables;
- append only configuration variables introduced by the new Release.

## ROBOT control contract

`toolbox/checks/` is the single source directory for all control examples
shipped by ANTONIA. Within this `template-ontology` development repository,
every control example must use an `example-` filename prefix. Installation,
update, and packaging must copy these files without renaming them.

The ontology project's `qc/profile.txt` is the sole configuration of which
ROBOT controls execute and at which severity. Merely shipping or copying a
query does not activate it. Do not introduce another activation list in
`config.env`, a shell script, the Makefile, directory enumeration, or a package
manifest. Runtime scripts may resolve a profile entry to the identically named
query copied into the configured destination directory, but they must not add
controls that are absent from `qc/profile.txt`.

The profile's optional third tab-separated field carries execution scope:
`project-source`, `non-mapping-source`, or `post-reason`; an omitted scope means
`post-reason`.

## Development commands

Run commands from the ANTONIA repository root:

```bash
make check
make test
make package VERSION=v1.0.0
make release VERSION=v1.0.0
make prerelease VERSION=v1.1.0-dev.1
```

`make check` validates shell syntax and required distribution files.
`make test` adds configuration-migration and archive-structure tests.
`make package` creates local ignored assets without publishing them.
`make release` is an external publication operation: it requires a clean
`main` branch exactly synchronized with `origin/main`, creates the tag, pushes
it, and creates the GitHub Release.
`make prerelease` requires a clean `dev` branch exactly synchronized with
`origin/dev`, creates and pushes the tag, and publishes a GitHub pre-Release
that is not marked as the latest stable version.

Do not invoke `make release` or `make prerelease` merely to test packaging.
Never bypass the clean-worktree or synchronized-branch guards: the published
archive must correspond exactly to the tagged commit.

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
