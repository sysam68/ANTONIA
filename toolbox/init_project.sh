#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# init_project.sh
# Initialize the host repository with the required directory structure and
# template files. Designed to be run after the released toolbox has been
# installed directly under the host repository's toolbox/ directory.
#
# Usage:
#   bash toolbox/init_project.sh                  # from host root
#   bash toolbox/init_project.sh --force          # overwrite existing files
#
# Creates:
#   Makefile          copied from the released toolbox
#   AGENTS.md         copied from the released toolbox
#   .agents/          ANTONIA-managed repository skills
#   .gitignore        extended with ANTONIA build/toolchain exclusions
#   config/           with template config.env and import.env
#   qc/               with example QC files
#   src/edit/         with myOntology-tbox.rdf and mapping example
#   src/sparql/       with ROBOT checks, updates, and analytics directories
#   src/shapes/       with an optional SHACL directory
#   tmp/              for build artifacts (git-ignored)
# -----------------------------------------------------------------------------
set -euo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# Resolve host root (the toolbox is installed in host_root/toolbox/)
TOOLBOX_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/.." && pwd)"

# Verify that this is a complete released toolbox.
if [ ! -f "$TOOLBOX_DIR/common.sh" ]; then
  echo "✖ init_project.sh must be run from within the ANTONIA toolbox"
  echo "  Expected: host_root/toolbox/init_project.sh"
  echo "  Current:  $TOOLBOX_DIR"
  exit 1
fi

echo "▶ Initializing ontology project in: $HOST_ROOT"

# Helper: create file if missing or --force
create_file() {
  local path="$1"
  local content="$2"
  local desc="${3:-}"
  if [ -f "$path" ] && [ "$FORCE" -eq 0 ]; then
    echo "  ⏭️  Skip: ${path#$HOST_ROOT/} (already exists)"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
  echo "  ✅ ${path#$HOST_ROOT/}${desc:+ — $desc}"
}

# Helper: copy a released template if missing or --force
create_from_template() {
  local path="$1"
  local template="$2"
  local desc="${3:-}"
  if [ -f "$path" ] && [ "$FORCE" -eq 0 ]; then
    echo "  ⏭️  Skip: ${path#$HOST_ROOT/} (already exists)"
    return 0
  fi
  if [ ! -f "$template" ]; then
    echo "✖ Missing ANTONIA template: $template" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$path")"
  cp "$template" "$path"
  echo "  ✅ ${path#$HOST_ROOT/}${desc:+ — $desc}"
}

# Helper: create directory
make_dir() {
  local dir="$1"
  mkdir -p "$dir"
  echo "  📁 ${dir#$HOST_ROOT/}/"
}

# Helper: append a root .gitignore rule without changing existing content.
ensure_gitignore_entry() {
  local path="$1"
  local entry="$2"

  if [ -f "$path" ] && grep -Fqx "$entry" "$path"; then
    echo "  ⏭️  Skip: .gitignore already excludes $entry"
    return 0
  fi

  if [ -s "$path" ] && [ -n "$(tail -c 1 "$path")" ]; then
    printf '\n' >> "$path"
  fi
  printf '%s\n' "$entry" >> "$path"
  echo "  ✅ .gitignore — exclude $entry"
}

# -----------------------------------------------------------------------------
# 1. host Makefile
# -----------------------------------------------------------------------------
cp "$TOOLBOX_DIR/Makefile" "$HOST_ROOT/Makefile"
echo "  ✅ Makefile — ontology build entry point from toolbox/Makefile"
cp "$TOOLBOX_DIR/AGENTS.md" "$HOST_ROOT/AGENTS.md"
echo "  ✅ AGENTS.md — ontology guidance from toolbox/AGENTS.md"
bash "$TOOLBOX_DIR/sync_agents.sh"
ensure_gitignore_entry "$HOST_ROOT/.gitignore" "tmp/"
ensure_gitignore_entry "$HOST_ROOT/.gitignore" ".tools/"
ensure_gitignore_entry "$HOST_ROOT/.gitignore" "src/edit/*.properties"

# -----------------------------------------------------------------------------
# 2. config/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/config"

create_from_template \
  "$HOST_ROOT/config/config.env" \
  "$TOOLBOX_DIR/templates/config/config.env" \
  "main configuration"

create_from_template \
  "$HOST_ROOT/config/import.env" \
  "$TOOLBOX_DIR/templates/config/import.env" \
  "import manifest (TSV format)"

# -----------------------------------------------------------------------------
# 3. qc/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/qc"

create_file "$HOST_ROOT/qc/profile.txt" $'ERROR\tduplicate_label\nERROR\tmultiple_labels\nERROR\tlabel_formatting\nERROR\tlabel_whitespace\nERROR\tinvalid_entity_uri\nERROR\tmissing_label\n' "ROBOT QC severity profile"

create_file "$HOST_ROOT/qc/allowlist.tsv" '' "QC allowlist (empty by default)"
create_file "$HOST_ROOT/qc/obo-expected.tsv" '' "OBO expected terms (empty by default)"

# -----------------------------------------------------------------------------
# 4. src/edit/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/edit/templates/instances"
make_dir "$HOST_ROOT/src/edit/imports"
make_dir "$HOST_ROOT/src/edit/modules"
make_dir "$HOST_ROOT/src/edit/annotations"
make_dir "$HOST_ROOT/src/edit/metadata"

create_from_template \
  "$HOST_ROOT/src/edit/myOntology.properties.example" \
  "$TOOLBOX_DIR/templates/config/ontop.properties.example" \
  "non-secret Ontop datasource example"

create_file "$HOST_ROOT/src/edit/myOntology-tbox.rdf" '<?xml version="1.0"?>
<rdf:RDF xmlns="https://example.org/ontology/myOntology/"
     xml:base="https://example.org/ontology/myOntology/"
     xmlns:owl="http://www.w3.org/2002/07/owl#"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
     xmlns:xml="http://www.w3.org/XML/1998/namespace"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
     xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
     xmlns:skos="http://www.w3.org/2004/02/skos/core#">
    <owl:Ontology rdf:about="https://example.org/ontology/myOntology/">
        <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Ontology"/>
        <rdfs:label xml:lang="en">My Ontology</rdfs:label>
        <rdfs:comment xml:lang="en">Template ontology created by toolbox init_project.sh</rdfs:comment>
        <owl:versionInfo>0.1.0</owl:versionInfo>
    </owl:Ontology>

    <!-- Example class -->
    <owl:Class rdf:about="https://example.org/ontology/myOntology/ExampleClass">
        <rdfs:label xml:lang="en">Example Class</rdfs:label>
        <rdfs:subClassOf rdf:resource="http://www.w3.org/2002/07/owl#Thing"/>
    </owl:Class>
</rdf:RDF>
' "TBox ontology (RDF/XML)"

create_file "$HOST_ROOT/src/edit/mapping-sourceIOnto-TargetOnto.rdf" '<?xml version="1.0"?>
<rdf:RDF xmlns="https://example.org/mapping/source-to-target#"
     xml:base="https://example.org/mapping/source-to-target/"
     xmlns:owl="http://www.w3.org/2002/07/owl#"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
     xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
    <owl:Ontology rdf:about="https://example.org/mapping/source-to-target/">
        <rdfs:label xml:lang="en">Source to Target Ontology Mapping</rdfs:label>
    </owl:Ontology>

    <!-- Example mapping: equivalentClass between source and target -->
    <owl:Class rdf:about="https://example.org/source/SourceClass">
        <owl:equivalentClass rdf:resource="https://example.org/target/TargetClass"/>
    </owl:Class>
</rdf:RDF>
' "Ontology mapping example"

# -----------------------------------------------------------------------------
# 5. src/sparql/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/sparql/checks"
make_dir "$HOST_ROOT/src/sparql/updates"
make_dir "$HOST_ROOT/src/sparql/reports"

create_file "$HOST_ROOT/src/sparql/checks/.gitkeep" '' "project ROBOT checks placeholder"

create_file "$HOST_ROOT/src/sparql/updates/project-ql.ru" '# SPARQL update: project ontology to OWL 2 QL for Ontop
# This is a template - customize for your ontology
DELETE { ?s ?p ?o }
INSERT { ?s ?p ?o }
WHERE  { ?s ?p ?o }
' "QL projection update template"

# -----------------------------------------------------------------------------
# 6. src/shapes/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/shapes/shacl"

create_file "$HOST_ROOT/src/shapes/shacl/.gitkeep" '' "optional SHACL shapes placeholder"

# -----------------------------------------------------------------------------
# 7. tmp/ (build artifacts)
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/tmp"
touch "$HOST_ROOT/tmp/.gitkeep"

# -----------------------------------------------------------------------------
# 8. Summary
# -----------------------------------------------------------------------------
echo ""
echo "✅ Project initialized successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit config/config.env to match your ontology settings"
echo "  2. Edit src/edit/myOntology-tbox.rdf with your ontology content"
echo "  3. Add GitHub Release imports to config/import.env"
echo "  4. Run: make install-robot"
echo "  5. Run: make install-semantic-tools when using OntoGPT, Ontop, or SHACL"
echo "  6. Run: make import && make all"
echo ""
echo "For more information, see the toolbox documentation."
