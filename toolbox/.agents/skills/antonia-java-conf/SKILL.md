---
name: antonia-java-conf
description: Generate the machine-specific ANTONIA JVM configuration through make java-conf.
---

# Generate the local JVM configuration

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make java-conf
```

Verify the ignored `config/java.conf` output and report the selected processor
and heap limits without committing the machine-specific file.
