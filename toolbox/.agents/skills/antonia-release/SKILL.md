---
name: antonia-release
description: Publish an ANTONIA ontology release through make release only when the user explicitly requests publication.
---

# Publish an ontology release

Read the repository-root `AGENTS.md` and the release documentation. This is an
external publication operation: proceed only when the user explicitly invokes
or requests release publication and supplies the intended `VERSION_TAG`.

Run from the repository root:

```bash
make release VERSION_TAG=<user-supplied-version>
```

Do not invent or silently change the version. Verify the resulting commit, tag,
remote publication, assets, and reports before claiming success. In particular,
verify the base, merged, QL, optional OBDA, and value-free
`.properties.example` assets, and confirm that no real `.properties` file or
credential value was published.
