---
name: antonia-progress
description: Run the five-stage ANTONIA ontology build pipeline with progress indicators.
---

# Run the pipeline with progress

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make progress
```

Preserve user-supplied `REASONER` and `FAIL_ON` assignments. Report the exact
stage at which execution stops and do not claim later stages ran.
