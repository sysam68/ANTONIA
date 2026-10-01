---
name: antonia-clean
description: Remove ANTONIA ontology build outputs under tmp through make clean.
---

# Clean build outputs

Read the repository-root `AGENTS.md`. Confirm that the current task does not
require preserving build evidence under `tmp/`, then run from the repository
root:

```bash
make clean
```

Report that `tmp/` was removed. Do not broaden cleanup beyond the Make target.
