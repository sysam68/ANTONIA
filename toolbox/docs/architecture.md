
# Ontology Project Architecture

## 1. Overview

This template organizes an ontology project into **modular components**:

- **TBox** (Schema): Defines classes, properties, and axioms
- **ABox** (Data): Declares individuals and their relationships
- **Annotations**: Labels, comments, metadata, and documentation
- **Templates**: TSV files to generate ontology modules programmatically
- **SPARQL**: Queries for quality control and validation
- **ROBOT report**: Canonical execution and reporting path for built-in and
  project SPARQL quality controls
- **SHACL**: Optional external graph constraints evaluated only when shapes
  exist
- **Design record**: Versioned rationale, evidence, decisions, and uncertainty

The goal is to **separate concerns** while enabling automated builds and versioning.

---

## 2. Directory Structure

```text
src/edit/                   authoritative TBox, optional ABox and OBDA
src/edit/templates/         TSV templates
src/edit/annotations/       annotation modules
src/shapes/shacl/           SHACL shapes
src/sparql/checks/          ROBOT report queries (?entity ?property ?value)
src/sparql/reports/         non-blocking queries
docs/ontology-design.md     modeling evidence and decisions
toolbox/                    managed ANTONIA runtime
tmp/                        ignored builds and extraction evidence
releases/                   ontology release artifacts
```

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
   - native and project SPARQL controls via the canonical ROBOT report
   - optional SHACL over the classified graph and optional ABox
   - OWL 2 DL compliance
   - non-blocking SPARQL analytics

5. **Release**
   - Package merged and classified ontologies
   - Optional diffs against last release
