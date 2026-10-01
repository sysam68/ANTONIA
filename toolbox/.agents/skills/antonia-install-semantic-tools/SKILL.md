---
name: antonia-install-semantic-tools
description: Install or repair the ANTONIA repository-local OntoGPT, Ontop, JDBC, and SHACL authoring toolchain.
---

# Install the semantic authoring toolchain

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make install-semantic-tools
```

The installer must write only below the ignored `.tools/` directory. Verify
`ontogpt --version`, `ontop --version`, and `pyshacl --version` through the
repository-local wrappers before reporting success. Do not install global
packages, use `sudo`, or disclose datasource and LLM credentials.
