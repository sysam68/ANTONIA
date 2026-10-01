# Interactive semantic authoring

ANTONIA separates three responsibilities instead of treating automated
extraction as an authoritative ontology.

## Ontologist

`$antonia-ontologist` elicits scope and competency questions, normalizes local
TXT, Markdown, text-based PDF, or DOCX sources, and uses OntoGPT with a
domain-neutral LinkML template. It may also inspect PostgreSQL/MySQL metadata
and bounded allowlisted samples. OntoGPT output is candidate evidence; the
skill is responsible for a reviewed RDF/XML TBox and a versioned ontology
design record.

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

Copy `src/edit/myOntology.properties.example` to the configured path and fill
credentials locally. The real `.properties` file is ignored and excluded from
every Release.

## Stewardship

`$antonia-onto-steward` maintains SHACL shapes, ROBOT report rules, and
blocking SPARQL checks. `make report` evaluates SHACL against the classified
local graph through pySHACL, writes `tmp/shacl_report.ttl` and
`tmp/shacl_report.txt`, then retains the existing ROBOT and SPARQL gates.
Violations block by default; Warning and Info severities remain visible.

## Shared workflow

All three skills require a clean worktree and propose a dedicated
`antonia/<skill>-<date>` branch. They write changes and show the diff, but never
commit, merge, push, or publish. Raw documents, samples, extraction results,
and bootstrap files remain under `tmp/`.
