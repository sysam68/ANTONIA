
---

## **`docs/architecture.md`**
```markdown
# Ontology Project Architecture

## 1. Overview

This template organizes an ontology project into **modular components**:

- **TBox** (Schema): Defines classes, properties, and axioms
- **ABox** (Data): Declares individuals and their relationships
- **Annotations**: Labels, comments, metadata, and documentation
- **Templates**: TSV files to generate ontology modules programmatically
- **SPARQL**: Queries for quality control and validation

The goal is to **separate concerns** while enabling automated builds and versioning.

---

## 2. Directory Structure

src/
tbox/ # Base ontology schema
abox/ # Instance data
annotations/ # Metadata ontologies
templates/ # TSV templates (classes, properties, individuals)
sparql/
checks/ # Blocking checks (must return empty)
reports/ # Non-blocking reports
toolbox/ # Automation scripts for ROBOT
tmp/ # Build outputs
releases/ # Versioned release packages



---

## 3. Build Process

The workflow follows these stages:

1. **Template Expansion**
   - TSV templates → TTL files
   - Separate TBox and ABox generation

2. **Merging**
   - Combine TBox, ABox, annotations, imports

3. **Reasoning**
   - Run classification with ELK, HermiT, or JFact

4. **Validation**
   - QC via ROBOT report
   - OWL 2 DL compliance
   - SPARQL checks

5. **Release**
   - Package merged and classified ontologies
   - Optional diffs against last release

