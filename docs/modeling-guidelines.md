# Modeling Guidelines

## 1. IRI Conventions

- **Base IRI**: `http://example.org/ontology/`
- **TBox entities**:
http://example.org/ontology/ServiceDomain

- **ABox instances**:
http://example.org/ontology/instance/SD_AccountManagement

- Always use lowercase for local names except where BIAN or external standards define otherwise.

---

## 2. Separation of TBox and ABox

- **TBox**:
- Classes, object properties, data properties, axioms
- Stored in `src/tbox/`
- **ABox**:
- Individuals and their assertions
- Stored in `src/abox/`

This separation enables:
- Clear maintenance of ontology structure
- Independent versioning of schema and data
- Easier template-driven generation

---

## 3. Instances in the Base IRI

- All individuals go under `/instance/`
- Example:
:SD_CustomerOnboarding rdf:type :ServiceDomain .


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
- **EquivalentClasses** for strict definitions
- **DisjointClasses** to avoid overlaps
- **Domain/Range** for properties
- **Named Individuals** for real-world instances

