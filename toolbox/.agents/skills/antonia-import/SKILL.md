---
name: antonia-import
description: Download and validate the external ontology Release assets configured for an ANTONIA project.
---

# Import external ontologies

Read the repository-root `AGENTS.md`, `config/import.env`, and the active XML
catalog. From the repository root, run:

```bash
make import
```

Report the concrete Release tag resolved for every `latest` selector and any
download or ontology-content validation failure.
