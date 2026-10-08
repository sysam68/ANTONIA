# Interactive semantic authoring

ANTONIA separates three responsibilities instead of treating automated
extraction as an authoritative ontology.

## Ontologist

`$antonia-ontologist` elicits scope and competency questions, normalizes local
TXT, Markdown, text-based PDF, or DOCX sources, and uses OntoGPT with a
domain-neutral LinkML template. It may also inspect PostgreSQL/MySQL metadata
and bounded allowlisted samples. OntoGPT output is candidate evidence; the
skill is responsible for a reviewed RDF/XML TBox and a versioned ontology
design record. It does not run `make all` or any individual stage of that
pipeline; reviewed changes are handed to the steward.

Set `ONTOGPT_MODEL` to a provider-qualified LiteLLM model. Non-local document
processing is forbidden unless `ONTOGPT_ALLOW_EXTERNAL_LLM=1`. Database values
have a separate `DB_SAMPLE_TO_LLM=1` authorization. API keys remain in the
provider environment or key store, never in `config.env`.

## Ontop mapping

`$antonia-ontop-mapping` reads the ignored file configured by
`ONTOP_PROPERTIES`, extracts database metadata, and creates a temporary Ontop
bootstrap. The bootstrap mirrors tables and is not the business ontology. The
skill confirms identity and IRI rules, aligns mapping targets with existing
ontology terms, writes the configured OBDA, and validates it with Ontop.

The relational `OBDA` mapping is distinct from the RDF ontology alignment file
configured by `MAPPINGS`. Only that RDF mapping ontology may declare
`owl:equivalentClass`; equivalences are rejected in every other source before
fusion.

Copy `src/edit/myOntology.properties.example` to the configured path and fill
credentials locally. The real `.properties` file is ignored and excluded from
every Release.

## Stewardship

`$antonia-onto-steward` is the sole pilot of the complete `make all` chain
(`generate`, `reason`, `project-ql`, `report`, and `validate`). It also
maintains ROBOT report rules and optional SHACL shapes.
Every project SPARQL control must return exactly
`?entity ?property ?value`; `make report` renders configuration sentinels and
injects only the project controls named in the configured `PROFILE` into a
temporary effective profile before producing the canonical ROBOT TSV/HTML
report under the configured `TARGET`. The native IRI ownership control runs
through `robot report` on project-owned sources before merge when enabled with
the `project-source` scope in the profile.
Temporary profiles are removed after execution. Blocking SPARQL
controls are not executed separately with `robot query`.

When shape files exist, `make report` also evaluates SHACL against the
classified local graph through pySHACL and writes `shacl_report.ttl` and
`shacl_report.txt` under the configured `TARGET`. Without shapes, pySHACL is
neither required nor invoked. Violations block by default; Warning and Info
severities remain visible.

## Shared workflow

All three skills propose a dedicated `antonia/<skill>-<date>` branch and require
a clean worktree before writing. The steward may validate reviewed uncommitted
changes already present on that branch. They show the diff but never commit,
merge, push, or publish. Raw documents, samples, extraction results, and
bootstrap files remain under the configured `TARGET`.
