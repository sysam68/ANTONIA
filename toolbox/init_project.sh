#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# init_project.sh
# Initialize the host repository with the required directory structure and
# template files. Designed to be run from the host repo root when this repo
# is used as a submodule (toolbox/).
#
# Usage:
#   bash toolbox/toolbox/init_project.sh          # from host root
#   bash toolbox/init_project.sh --force          # overwrite existing files
#
# Creates:
#   config/           with template config.env and import.env
#   qc/               with example QC files
#   src/edit/         with myOntology-tbox.rdf and mapping example
#   src/sparql/       with checks, updates, reports directories
#   src/shapes/       with SHACL directory
#   tmp/              for build artifacts (git-ignored)
# -----------------------------------------------------------------------------
set -euo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# Resolve host root (assumes we are in host_root/toolbox/toolbox/)
TOOLBOX_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/../.." && pwd)"

# Verify we are in a submodule layout
if [ ! -f "$TOOLBOX_DIR/common.sh" ]; then
  echo "✖ init_project.sh must be run from within the toolbox submodule"
  echo "  Expected: host_root/toolbox/toolbox/init_project.sh"
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

# Helper: create directory
make_dir() {
  local dir="$1"
  mkdir -p "$dir"
  echo "  📁 ${dir#$HOST_ROOT/}/"
}

# -----------------------------------------------------------------------------
# 1. config/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/config"

create_file "$HOST_ROOT/config/config.env" '\
# Ontology files
TBOX=src/edit/myOntology-tbox.rdf
ABOX=src/edit/myOntology-abox.rdf
MAPPINGS=
OBDA=src/edit/myOntology-tbox.obda
CATALOG=src/edit/catalog-v001.xml
QL_PROJECTION_UPDATE=src/sparql/updates/project-ql.ru

# Quality Check Files
PROFILE=qc/profile.txt
ALLOWLIST=qc/allowlist.tsv
EXPECTED=qc/obo-expected.tsv
FAIL_ON=ERROR     # seuil de sévérité (NONE|INFO|WARN|ERROR)
QC_STRICT=1       # 1 = bloque, 0 = n’arrête pas le build

# Base IRIs
BASE_IRI=https://example.org/ontology/myOntology/
INSTANCE_BASE_IRI=https://example.org/id/myOntology/

# Paths
IMPORTS_DIR=src/edit/imports
MODULES_DIR=src/edit/modules
ANNOTATIONS_DIR=src/edit/annotations
TEMPLATE_DIRS=src/edit/templates,src/edit/templates/instances,src/edit/annotations
SHAPES_DIR=src/shapes
SPARQL_CHECKS=src/sparql/checks
SPARQL_REPORTS=src/sparql/reports
TARGET=tmp
RELEASES=releases

# Build settings
REASONER=HERMIT
REFERENCE_PROFILE=DL
ONTOP_PROFILE=QL
ONTOLOGY_NAME=my-ontology
JAVA_CONF=config/java.conf

# Git settings
GIT_MAIN_BRANCH=main
GIT_DEV_BRANCH=dev
RELEASE_TAG_PREFIX=my-v
USE_GH=1
' "main configuration"

create_file "$HOST_ROOT/config/import.env" '\
# GitHub repository URL#release asset<TAB>release tag or latest<TAB>local basename
# Example:
# https://github.com/example/external-ontology.git#ontology.rdf<TAB>v1.0<TAB>external
' "import manifest (TSV format)"

# Copy java.conf if present in toolbox
if [ -f "$TOOLBOX_DIR/../config/java.conf" ]; then
  cp "$TOOLBOX_DIR/../config/java.conf" "$HOST_ROOT/config/java.conf.template"
  echo "  📋 config/java.conf.template (from toolbox)"
fi

# -----------------------------------------------------------------------------
# 2. qc/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/qc"

create_file "$HOST_ROOT/qc/profile.txt" '\
ERROR\tduplicate_label
ERROR\tmultiple_labels
ERROR\tlabel_formatting
ERROR\tlabel_whitespace
ERROR\tinvalid_entity_uri
' "QC severity profile"

create_file "$HOST_ROOT/qc/allowlist.tsv" '' "QC allowlist (empty by default)"
create_file "$HOST_ROOT/qc/obo-expected.tsv" '' "OBO expected terms (empty by default)"

# -----------------------------------------------------------------------------
# 3. src/edit/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/edit/templates/instances"
make_dir "$HOST_ROOT/src/edit/imports"
make_dir "$HOST_ROOT/src/edit/modules"
make_dir "$HOST_ROOT/src/edit/annotations"
make_dir "$HOST_ROOT/src/edit/metadata"

create_file "$HOST_ROOT/src/edit/myOntology-tbox.rdf" '<?xml version="1.0"?>
<rdf:RDF xmlns="https://example.org/ontology/myOntology#"
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
    <owl:Class rdf:about="https://example.org/ontology/myOntology#ExampleClass">
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
# 4. src/sparql/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/sparql/checks"
make_dir "$HOST_ROOT/src/sparql/updates"
make_dir "$HOST_ROOT/src/sparql/reports"

create_file "$HOST_ROOT/src/sparql/checks/example_check.rq" '\
# SPARQL check: example - must return empty results to pass
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?class ?label
WHERE {
  ?class a owl:Class .
  OPTIONAL { ?class rdfs:label ?label }
  FILTER(!BOUND(?label))
}
' "Example SPARQL check"

create_file "$HOST_ROOT/src/sparql/updates/project-ql.ru" '\
# SPARQL update: project ontology to OWL 2 QL for Ontop
# This is a template - customize for your ontology
DELETE { ?s ?p ?o }
INSERT { ?s ?p ?o }
WHERE  { ?s ?p ?o }
' "QL projection update template"

# -----------------------------------------------------------------------------
# 5. src/shapes/
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/src/shapes/shacl"

create_file "$HOST_ROOT/src/shapes/shacl/ontology-shapes.ttl" '\
# SHACL shapes for ontology validation
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# Example shape: every class must have a label
_:ClassShape
    a sh:NodeShape ;
    sh:targetClass owl:Class ;
    sh:property [
        sh:path rdfs:label ;
        sh:minCount 1 ;
        sh:message "Every class must have an rdfs:label" ;
    ] .
' "SHACL shapes (Turtle)"

# -----------------------------------------------------------------------------
# 6. tmp/ (build artifacts)
# -----------------------------------------------------------------------------
make_dir "$HOST_ROOT/tmp"
touch "$HOST_ROOT/tmp/.gitkeep"

# -----------------------------------------------------------------------------
# 7. Summary
# -----------------------------------------------------------------------------
echo ""
echo "✅ Project initialized successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit config/config.env to match your ontology settings"
echo "  2. Edit src/edit/myOntology-tbox.rdf with your ontology content"
echo "  3. Add GitHub Release imports to config/import.env"
echo "  4. Run: make install-robot"
echo "  5. Run: make import && make all"
echo ""
echo "For more information, see the toolbox documentation."
