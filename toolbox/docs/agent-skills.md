# ANTONIA agent skills

ANTONIA installs its managed Codex skills under the ontology repository root at
`.agents/skills/`. Use `/skills` to browse them in Codex CLI or the IDE, or
mention a skill directly with `$skill-name`.

Repository-distributed skills cannot define new top-level slash commands such
as `/antonia-release`. Custom slash prompts are local-only and deprecated, so
ANTONIA uses the supported skill invocation syntax instead.

| Skill invocation | Make target | Required input or boundary |
| --- | --- | --- |
| `$antonia-help` | `make help` | None |
| `$antonia-init-project` | `make init-project` | Preserves existing files |
| `$antonia-init-x` | `make init-x` | Inline Make recipe; no dedicated script |
| `$antonia-install-robot` | `make install-robot` | Local `.tools/` only |
| `$antonia-install-semantic-tools` | `make install-semantic-tools` | Local `.tools/` only |
| `$antonia-update` | `make update-antonia` | Stable by default; script supports `-dev` and `-version=<tag>` |
| `$antonia-java-conf` | `make java-conf` | Generates ignored local config |
| `$antonia-import` | `make import` | Uses `config/import.env` |
| `$antonia-test-imports` | `make test-imports` | Import and closure tests |
| `$antonia-test-qc` | `make test-qc` | QC regression tests |
| `$antonia-test-profiles` | `make test-profiles` | DL and QL profile tests |
| `$antonia-test-equivalences` | `make test-equivalences` | Semantic contracts |
| `$antonia-test-release` | `make test-release` | Never publishes |
| `$antonia-diff` | `make diff` | Requires `OLD` and `NEW` |
| `$antonia-clean` | `make clean` | Removes the configured `TARGET` |
| `$antonia-release` | `make release` | Explicit publication request and `VERSION_TAG` |

Interactive skills do not correspond to a single Make target:

| Skill invocation | Responsibility | Required boundary |
| --- | --- | --- |
| `$antonia-ontologist` | Create or enrich the TBox from documents or PostgreSQL/MySQL; never runs build stages | Clean dedicated branch; external-LLM consent |
| `$antonia-ontop-mapping` | Align a JDBC datasource with the existing ontology in OBDA | Ignored `.properties`; explicit identity rules |
| `$antonia-onto-steward` | Author controls and exclusively pilot `make all` | Preserves Make assignments; verifies every completed stage |

`$antonia-onto-steward` owns the complete non-import chain: `generate`,
`reason`, `project-ql`, `report`, and `validate`. The former workflow, all,
progress, and per-stage skills were removed because they duplicated this single
responsibility. The underlying Make targets remain available for direct
diagnosis, but agents must use the steward for the complete chain.

Examples:

```text
$antonia-init-project
$antonia-install-semantic-tools
$antonia-ontologist
$antonia-onto-steward REASONER=hermit FAIL_ON=WARN SHACL_FAIL_ON=VIOLATION
$antonia-diff OLD=releases/old.<format> NEW=<TARGET>/classified.<format>
$antonia-release VERSION_TAG=2026-10-01
```

Project controls under the directory configured by `SPARQL_CHECKS` must return
exactly `?entity ?property ?value`; `make report` injects only those named in
the file configured by `PROFILE` into the effective ROBOT profile. The optional
third profile field selects `project-source`, `non-mapping-source`, or
`post-reason` scope;
an omitted scope means `post-reason`. The configured `SPARQL_REPORTS` directory
is reserved for non-blocking analytics. External
pySHACL validation runs only when SHACL shape files exist.

Restart Codex if newly installed skills do not appear in `/skills` immediately.
