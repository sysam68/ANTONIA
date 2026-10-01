---
name: antonia-ontologist
description: Interactively create or enrich an ANTONIA ontology from documents or an authorized PostgreSQL/MySQL datasource using OntoGPT for structured candidate extraction.
---

# ANTONIA ontologist

Create a reviewable ontology proposal, not an unqualified transcription of
source words, tables, or rows. Read the repository-root `AGENTS.md`,
`config/config.env`, and [the authoring contract](references/authoring-contract.md)
before acting.

## Establish a safe workspace

- Require a clean Git worktree. If the current branch is not dedicated to the
  task, offer to create `antonia/ontologist-<date>` before writing.
- Reuse configured TBox, IRI, language, and path values. Ask only for missing
  intent: subject, audience, purpose, competency questions, and sources.
- Run `make install-semantic-tools` when the local OntoGPT toolchain is absent.
- Store normalized inputs, extraction results, database metadata, and samples
  under `tmp/antonia-ontologist/`.

## Extract candidates

For TXT, Markdown, text-based PDF, or DOCX input, normalize the document with
`scripts/normalize_document.py`. Run OntoGPT with
`toolbox/run_ontogpt.sh`, which uses
`assets/antonia_ontology_candidates.yaml` and the configured model.

Before a non-local model receives document content, require
`ONTOGPT_ALLOW_EXTERNAL_LLM=1`. Never infer consent from the presence of an API
key. For a database source, extract metadata with `ontop extract-db-metadata`.
Sample only tables explicitly listed in `DB_SAMPLE_TABLES`, with the configured
row limit, through `toolbox/sample_database.py`. Do not send sample values to
an LLM unless `DB_SAMPLE_TO_LLM=1`.

## Build the ontology

- Treat OntoGPT results as candidates with evidence, not accepted semantics.
- Distinguish classes, individuals, object properties, data properties, and
  annotations. Do not turn every noun, table, column, or record into a class.
- Preserve existing axioms. Stop on an IRI collision, incompatible definition,
  destructive rename, or deletion until the user resolves it.
- Write accepted axioms to the configured RDF/XML TBox. Keep generated or raw
  intermediates out of `src/`.
- Create or update the configured ontology-design record from
  `assets/ontology-design-template.md`, recording accepted and rejected
  candidates, source evidence, assumptions, and unresolved boundaries.

Run the relevant ANTONIA build and profile checks. Finish with the complete Git
diff and validation evidence. Do not commit, push, merge, or publish.
