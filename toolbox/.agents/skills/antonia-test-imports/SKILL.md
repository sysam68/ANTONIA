---
name: antonia-test-imports
description: Run ANTONIA tests for GitHub Release imports and the self-contained ontology import closure.
---

# Test imports

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make test-imports
```

Report Release-download and import-closure failures separately. Do not report a
passing import closure when residual `owl:imports` remain.
