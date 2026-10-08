---
name: antonia-release
description: Publish an ANTONIA ontology release through make release only when the user explicitly requests publication.
---

# Publish an ontology release

Read the repository-root `AGENTS.md` and the release documentation. This is an
external publication operation: proceed only when the user explicitly invokes
or requests release publication. `VERSION_TAG` is optional.

Run from the repository root:

```bash
make release
# or, only when the user requests an exact immutable version:
make release VERSION_TAG=<user-supplied-version>
```

Without an explicit version, allow `release.sh` to select the next daily
`YYYY-MM-DD.NNN` value: `.000` first, then `.001`, `.002`, and so on. Do not
invent another version or override a version supplied by the user. Verify the
resulting commit, tag, remote publication, assets, and reports before claiming
success. In particular, verify the base, merged, QL, optional OBDA, and value-free
`.properties.example` assets, and confirm that no real `.properties` file or
credential value was published.
