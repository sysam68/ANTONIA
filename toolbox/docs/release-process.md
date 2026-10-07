# Release Process

## 1. Overview

The release process creates a **versioned package** of the ontology, including:
- Base ontology from `TBOX` (`<name>.<format>`, with a compatibility
  `<name>.owl` copy)
- Merged ontology (`<name>-merged.<format>`)
- Every RDF/Turtle mapping under `MAPPINGS_DIR`, with a `mapping-` asset prefix
- Every RDF/Turtle service catalog under `SERVICES_DIR`, with a `service-`
  asset prefix
- QC and diff reports (if available)

The configured directories default to `src/edit/mappings/` and
`src/edit/services/`. Their direct `.rdf` and `.ttl` files are Release inputs.
An existing `mapping-` or `service-` filename prefix is preserved; otherwise
the corresponding prefix is added only to the Release asset. Other extensions,
including `.properties`, are never selected, and `.properties` files are
rejected from Release trees.

---

## 2. Script Sequence

1. **Generate from templates**  
   ```bash
   ./toolbox/generate_from_templates.sh
2. **Run reasoning**
   ```bash
   ./toolbox/reason.sh
3. **Run QC reports**
   ```bash
   ./toolbox/report.sh
4. **Validate ontology**
   ```bash
   ./toolbox/validate.sh
5. **Create release package**
   ```bash
   ./toolbox/release.sh

## 3. Versioning
Releases are stored under releases/YYYY-MM-DD/
Git tags are created automatically if the repository is under Git control
Example:
```swift
releases/2025-08-13/
  ontology.<format>
  ontology.owl
  ontology-merged.<format>
  diff.html
  qc_report.tsv

## 4. Best Practices
Always commit before creating a release
Tag releases for reproducibility
Keep TBox and ABox changes in separate commits when possible
Update documentation when modeling rules change
