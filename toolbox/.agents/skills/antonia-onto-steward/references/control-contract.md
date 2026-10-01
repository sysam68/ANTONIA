# Quality-control contract

Choose the executable mechanism by the graph being constrained:

- SHACL for node/property shapes over the classified graph and ABox;
- ROBOT report for its maintained ontology-quality rules;
- blocking SPARQL SELECT for project-specific graph patterns that must return
  no rows.

Each rule needs a stable identifier, message, target, severity, rationale, and
positive/negative fixture. Under the default configuration, SHACL Violations
block `make report`; Warnings and Info remain visible but non-blocking.

Do not derive a business constraint merely from SQL nullability or a primary
key. Database constraints may support a proposed rule but do not establish its
business meaning. V1 validates the local classified graph and does not
materialize the relational datasource for SHACL.
