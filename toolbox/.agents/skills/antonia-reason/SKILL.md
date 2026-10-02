---
name: antonia-reason
description: Merge the ontology import closure and classify the ANTONIA OWL 2 DL reference ontology.
---

# Merge and reason

Read the repository-root `AGENTS.md` and `config/config.env`. From the
repository root, run:

```bash
make reason
```

Preserve a user-supplied `REASONER=hermit|ELK|jfact`; do not invent an override.
When ontology inputs exist, verify that the merged output has no residual
`owl:imports` and report reasoning failures with their actual evidence. When no
ontology file exists yet, report the successful no-op message instead of
expecting merge or classification outputs.
