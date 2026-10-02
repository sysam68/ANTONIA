# Quality-control contract

ROBOT is the mandatory execution and reporting path for ontology-quality and
SPARQL controls:

- ROBOT report for its maintained ontology-quality rules;
- custom ROBOT report queries for project-specific graph patterns. They live
  under the configured checks directory, return exactly
  `?entity ?property ?value`, and return no rows for conforming data;
- the configured reports directory contains non-blocking analytics, never
  quality-control gates.

External validation is limited to SHACL when an explicit node/property shape
cannot be replaced without losing SHACL semantics. If no `.ttl`, `.rdf`, or
`.owl` shape exists under the configured shapes directory, pySHACL must not be
required or invoked.

The toolbox-native `forbidden_iri` query is always injected into the effective
ROBOT profile. `toolbox/report.sh` renders its `BASE_IRI` and
`INSTANCE_BASE_IRI` sentinels from `config/config.env`; projects must not copy,
shadow, or duplicate this managed rule.

Each rule needs a stable identifier, message, target, severity, rationale, and
positive/negative fixture. For custom ROBOT queries, bind the stable rule IRI
to `?property` and actionable evidence to `?value`. Under the default
configuration, ROBOT errors and SHACL Violations block `make report`; SHACL
Warnings and Info remain visible but non-blocking.

Do not derive a business constraint merely from SQL nullability or a primary
key. Database constraints may support a proposed rule but do not establish its
business meaning. V1 validates the local classified graph and does not
materialize the relational datasource for SHACL.
