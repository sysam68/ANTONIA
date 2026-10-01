# Ontop mapping contract

The database schema is not the ontology. Ontop bootstrap provides a mechanical
starting point that must be aligned with the conceptual model.

For every mapping, record or confirm:

- a stable mapping identifier;
- the target class or property IRI already present in the ontology;
- the SQL source and every projected column used by the target template;
- the instance identity rule and treatment of nullable key components;
- datatype conversion and language-tag behavior;
- joins required for object properties;
- a representative SPARQL SELECT query and expected result shape.

Reject mappings whose target term is absent, whose projected placeholder is
not returned by the SQL query, or whose identity can collapse distinct rows.
Do not include passwords, connection strings, or sampled values in the mapping
decision record.
