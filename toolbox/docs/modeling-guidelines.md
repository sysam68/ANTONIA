# Modeling Guidelines

## 1. IRI Conventions

- **Base IRI**: use the value configured by `BASE_IRI`
- **TBox entities**:
`<BASE_IRI>ServiceDomain`

- **ABox instances**:
`<INSTANCE_BASE_IRI>SD_AccountManagement`

Before merge, the native `forbidden_iri` ROBOT report rule enforces these
configured bases on the project-owned TBox, ABox, generated modules, and
annotations, and rejects version segments in schema entity IRIs. Imported
ontologies and the ontology configured by `MAPPINGS` are excluded because their
entity namespaces are externally owned.

- Always use lowercase for local names except where BIAN or external standards define otherwise.

---

## 2. Separation of TBox and ABox

- **TBox**:
- Classes, object properties, data properties, axioms
- Stored in the path configured by `TBOX`
- **ABox**:
- Individuals and their assertions
- Stored in the optional path configured by `ABOX`

This separation enables:
- Clear maintenance of ontology structure
- Independent versioning of schema and data
- Easier template-driven generation

---

## 3. Instances in the Instance Base IRI

- All named individuals use the configured `INSTANCE_BASE_IRI`.
- Example:
`<INSTANCE_BASE_IRI>SD_CustomerOnboarding rdf:type <BASE_IRI>ServiceDomain .`


---

## 4. Templates

Use TSV templates for:
- Classes
- Object properties
- Data properties
- Individuals

**Example TSV (individuals.tsv)**:
| ID                      | Label                  | Type            | RelatedTo               |
|------------------------|------------------------|----------------|-------------------------|
| SD_AccountManagement   | Account Management     | ServiceDomain  | BD_Accounts             |

---

## 5. Modeling Patterns

- **SubClassOf hierarchy** for taxonomy
- **EquivalentClasses** only in the ontology-to-ontology file configured by
  `MAPPINGS`; they are forbidden in the TBox, ABox, imports, generated modules,
  and annotations
- **DisjointClasses** to avoid overlaps
- **Domain/Range** for properties
- **Named Individuals** for real-world instances
