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
| `$antonia-generate` | `make generate` | Uses configured TSV templates |
| `$antonia-reason` | `make reason` | Optional `REASONER` |
| `$antonia-project-ql` | `make project-ql` | Requires merged ontology |
| `$antonia-report` | `make report` | Optional `FAIL_ON` |
| `$antonia-validate` | `make validate` | Validates DL and QL outputs |
| `$antonia-all` | `make all` | Complete non-import pipeline |
| `$antonia-progress` | `make progress` | Same pipeline with progress |
| `$antonia-test-imports` | `make test-imports` | Import and closure tests |
| `$antonia-test-qc` | `make test-qc` | QC regression tests |
| `$antonia-test-profiles` | `make test-profiles` | DL and QL profile tests |
| `$antonia-test-equivalences` | `make test-equivalences` | Semantic contracts |
| `$antonia-test-release` | `make test-release` | Never publishes |
| `$antonia-diff` | `make diff` | Requires `OLD` and `NEW` |
| `$antonia-clean` | `make clean` | Removes `tmp/` |
| `$antonia-release` | `make release` | Explicit publication request and `VERSION_TAG` |

Interactive skills do not correspond to a single Make target:

| Skill invocation | Responsibility | Required boundary |
| --- | --- | --- |
| `$antonia-ontologist` | Create or enrich the TBox from documents or PostgreSQL/MySQL | Clean dedicated branch; external-LLM consent |
| `$antonia-ontop-mapping` | Align a JDBC datasource with the existing ontology in OBDA | Ignored `.properties`; explicit identity rules |
| `$antonia-onto-steward` | Author SHACL, ROBOT, and SPARQL quality gates | Positive/negative examples and severity |

Examples:

```text
$antonia-init-project
$antonia-install-semantic-tools
$antonia-ontologist
$antonia-reason REASONER=hermit
$antonia-report FAIL_ON=WARN
$antonia-diff OLD=releases/old.<format> NEW=tmp/classified.<format>
$antonia-release VERSION_TAG=2026-10-01
```

Restart Codex if newly installed skills do not appear in `/skills` immediately.
