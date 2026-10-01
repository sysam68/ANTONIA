---
name: antonia-init-x
description: Restore executable permissions on ANTONIA toolbox shell scripts through make init-x.
---

# Restore toolbox script permissions

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make init-x
```

The `init-x` recipe is implemented directly in the Makefile with
`chmod +x toolbox/*.sh`. There is intentionally no dedicated script for this
target. Do not replace the Make invocation with a guessed script path.

Report which toolbox scripts, if any, changed executable status.
