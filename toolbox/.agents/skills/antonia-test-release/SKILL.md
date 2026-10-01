---
name: antonia-test-release
description: Test ANTONIA ontology release resumability, idempotency, and mapping-ontology packaging without publishing.
---

# Test ontology release behavior

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make test-release
```

This target is a local test and must not be replaced with `make release`.
Report idempotency and mapping-ontology results separately.
