---
name: antonia-init-project
description: Initialize missing ontology-project files from the installed ANTONIA toolbox through make init-project.
---

# Initialize the ontology project

Read the repository-root `AGENTS.md` and confirm that the installed toolbox is
managed by ANTONIA. From the repository root, run:

```bash
make init-project
```

Report created and skipped files. Preserve existing project files and do not
substitute a forced initialization unless the user explicitly asks for it.
