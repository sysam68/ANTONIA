# Ontology authoring contract

## Inputs

V1 accepts local UTF-8 text, Markdown, text-based PDF, DOCX, PostgreSQL, and
MySQL. Scanned-document OCR, remote URL ingestion, Neo4j, and unbounded database
profiling are outside the workflow.

## Minimum elicitation

Establish the ontology purpose, intended users, competency questions, scope,
language, base IRI, instance IRI, and authoritative sources. Separate facts
found in a source from modeling decisions and hypotheses.

## Candidate acceptance

A class or property needs a definition, a distinct role in at least one
competency question, and supporting evidence. Mark uncertain candidates rather
than silently strengthening them into logical axioms. Do not assert
equivalence, disjointness, cardinality, domain, or range solely from lexical
similarity.

## Database boundaries

Database metadata describes a physical model, not automatically a business
ontology. Primary and foreign keys are useful evidence for identity and
relations, but require semantic confirmation. Samples are temporary supporting
evidence and must never be copied into the ontology-design record.

## Review outcome

Report accepted axioms, rejected candidates, unresolved items, source
coverage, validation results, and the Git diff. Leave all changes uncommitted.
