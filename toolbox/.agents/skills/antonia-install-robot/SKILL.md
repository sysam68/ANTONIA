---
name: antonia-install-robot
description: Install or repair the ANTONIA repository-local ROBOT and Java toolchain.
---

# Install the local ROBOT toolchain

Read the repository-root `AGENTS.md`. From the repository root, run:

```bash
make install-robot
```

Verify the resulting local toolchain instead of reporting success from the exit
status alone. Do not install global packages or use `sudo`.
