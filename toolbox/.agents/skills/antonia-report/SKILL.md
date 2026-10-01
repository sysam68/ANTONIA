---
name: antonia-report
description: Run ANTONIA quality-control reports and blocking SPARQL checks.
---

# Run quality-control reports

Read the repository-root `AGENTS.md` and the QC profile. From the repository
root, run:

```bash
make report
```

Preserve a user-supplied `FAIL_ON=ERROR|WARN|NONE`. Inspect the generated reports
and distinguish blocking errors, warnings, and allowlisted findings.
