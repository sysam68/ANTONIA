---
name: antonia-ontop-mapping
description: Interactively generate or evolve an Ontop OBDA mapping from an authorized PostgreSQL/MySQL schema while aligning it with the configured ANTONIA ontology.
---

# ANTONIA Ontop mapping

Read the repository-root `AGENTS.md`, `config/config.env`, the configured TBox,
and [the mapping contract](references/mapping-contract.md) before acting.

Require a clean worktree and a dedicated `antonia/ontop-mapping-<date>` branch
before writing. Run `make install-semantic-tools` when the local Ontop wrapper
is absent. Never print the configured properties file or credentials.

## Build the technical baseline

Use the path in `ONTOP_PROPERTIES` and write every intermediate under
`TARGET/antonia-ontop-mapping/`:

```bash
ontop extract-db-metadata -p <properties> -o <TARGET>/db-metadata.json
ontop bootstrap -b <instance-base-iri> -p <properties> \
  -m <TARGET>/bootstrap.obda -t <TARGET>/bootstrap.owl
```

The bootstrap ontology mirrors the database and is evidence only. Do not merge
it into the authoritative TBox or copy it into a Release.

`owl:equivalentClass` assertions are allowed only in the ontology-to-ontology
file configured by `MAPPINGS`. Do not confuse that RDF alignment ontology with
the relational OBDA file configured by `OBDA`.

## Align and validate

- Confirm entity identity, primary keys, instance IRI templates, joins,
  nullable columns, and target classes/properties.
- Map to terms in the configured TBox or QL projection. Do not invent target
  IRIs or accept lexical similarity as proof of equivalence.
- When the configured OBDA exists, preserve unrelated mappings and stable
  mapping identifiers. Stop on conflicting IDs or ambiguous alignments.
- Validate with `ontop validate`, then execute representative bounded SELECT
  queries with `ontop query` against the datasource.

Write only the reviewed result to `OBDA`. Present the mapping decisions,
validation evidence, and Git diff. Do not commit, push, merge, or publish.
