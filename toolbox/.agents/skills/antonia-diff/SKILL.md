---
name: antonia-diff
description: Compare two ontology artifacts semantically through the ANTONIA Make diff target.
---

# Compare ontology versions

Read the repository-root `AGENTS.md`. Require explicit `OLD` and `NEW` paths
from the user or task context, then run from the repository root:

```bash
make diff OLD=<old-ontology> NEW=<new-ontology>
```

Do not guess either artifact. Summarize semantic additions, removals, and the
location of the full diff output.
