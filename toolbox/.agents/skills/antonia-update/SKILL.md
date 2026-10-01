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

Use the maintained script directly for development channels:

```bash
./toolbox/update-antonia.sh -dev
./toolbox/update-antonia.sh -dev -version=<tag>
```

The first form resolves the most recent GitHub pre-Release published from the
ANTONIA `dev` branch and requires `gh`; it deliberately ignores a stable-channel
`ANTONIA_VERSION` pin. The second selects an explicit immutable tag. Preserve a
user-supplied `ANTONIA_VERSION` for stable updates when no command-line version
is provided. Report the channel, previous and installed versions, configuration
additions, and any managed-skill conflict.
