---
name: antonia-all
description: Run the five-stage ANTONIA ontology build pipeline through the all Make target.
---

# Run the ANTONIA build pipeline

Read the repository-root `AGENTS.md` and verify that `toolbox/.antonia-managed`
exists. From the repository root, run:

```bash
make all
```

Preserve any user-supplied Make assignments such as `REASONER` or `FAIL_ON`.
Report the failing stage and its evidence when the pipeline does not complete.
