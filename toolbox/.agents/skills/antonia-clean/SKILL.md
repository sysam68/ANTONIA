---
name: antonia-clean
description: Remove the configured ANTONIA ontology build directory through make clean.
---

# Clean build outputs

Read the repository-root `AGENTS.md` and `config/config.env`. Resolve `TARGET`
and confirm that the current task does not require preserving build evidence
under that directory, then run from the repository root:

```bash
make clean
```

Report the configured directory that was removed. Do not broaden cleanup beyond
the Make target.
