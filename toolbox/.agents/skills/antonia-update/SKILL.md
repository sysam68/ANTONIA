---
name: antonia-update
description: Update an installed ANTONIA toolbox and its managed root files and skills through make update-antonia.
---

# Update ANTONIA

Read the repository-root `AGENTS.md` and confirm that
`toolbox/.antonia-managed` exists. From the repository root, run:

```bash
make update-antonia
```

Preserve a user-supplied `ANTONIA_VERSION` when present. Report the previous and
installed versions, configuration additions, and any managed-skill conflict.
