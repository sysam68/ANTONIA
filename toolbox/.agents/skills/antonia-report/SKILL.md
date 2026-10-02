---
name: antonia-report
description: Run the canonical ROBOT quality-control report and optional external SHACL validation.
---

# Run quality-control reports

Read the repository-root `AGENTS.md` and the QC profile. From the repository
root, run:

```bash
make report
```

Preserve a user-supplied `FAIL_ON=ERROR|WARN|NONE`. Confirm that native and
project SPARQL controls were injected into `tmp/robot-profile.txt`; no blocking
SPARQL control may run through a separate `robot query` gate. Inspect the
generated ROBOT report and distinguish blocking errors, warnings, and
allowlisted findings. Inspect the separate SHACL report only when shape files
exist.
