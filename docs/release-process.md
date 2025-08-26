# Release Process

## 1. Overview

The release process creates a **versioned package** of the ontology, including:
- Classified ontology (`<name>.ttl`)
- Merged ontology (`<name>-merged.ttl`)
- QC and diff reports (if available)

---

## 2. Script Sequence

1. **Generate from templates**  
   ```bash
   ./scripts/generate_from_templates.sh
2. **Run reasoning**
   ```bash
   ./scripts/reason.sh
3. **Run QC reports**
   ```bash
   ./scripts/report.sh
4. **Validate ontology**
   ```bash
   ./scripts/validate.sh
5. **Create release package**
   ```bash
   ./scripts/release.sh

## 3. Versioning
Releases are stored under releases/YYYY-MM-DD/
Git tags are created automatically if the repository is under Git control
Example:
```swift
releases/2025-08-13/
  ontology.ttl
  ontology-merged.ttl
  diff.html
  qc_report.tsv

## 4. Best Practices
Always commit before creating a release
Tag releases for reproducibility
Keep TBox and ABox changes in separate commits when possible
Update documentation when modeling rules change


