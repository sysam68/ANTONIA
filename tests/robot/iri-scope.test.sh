#!/usr/bin/env bash
# Verify that example-forbidden_iri runs before merge only on project-owned ontology
# sources, never on imported ontologies or the configured MAPPINGS ontology.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/antonia-iri-scope.XXXXXX")"
HOST_ROOT="$TEST_ROOT/host"
BIN="$TEST_ROOT/bin"

cleanup() {
  case "$TEST_ROOT" in
    "${TMPDIR:-/tmp}"/antonia-iri-scope.*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$HOST_ROOT/toolbox/checks" "$HOST_ROOT/config" "$HOST_ROOT/qc" \
  "$HOST_ROOT/src/sparql/checks" \
  "$HOST_ROOT/src/edit/imports" "$HOST_ROOT/src/edit/modules" \
  "$HOST_ROOT/src/edit/annotations" "$TEST_ROOT/captured" "$BIN"
cp "$ROOT/toolbox/common.sh" "$HOST_ROOT/toolbox/common.sh"
cp "$ROOT/toolbox/reason.sh" "$HOST_ROOT/toolbox/reason.sh"
cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$HOST_ROOT/toolbox/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$HOST_ROOT/toolbox/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$HOST_ROOT/src/sparql/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$HOST_ROOT/src/sparql/checks/"
printf '%s\n' \
  $'ERROR\texample-forbidden_iri\tproject-source' \
  $'ERROR\texample-forbidden_equivalence\tnon-mapping-source' \
  > "$HOST_ROOT/qc/profile.txt"

cat > "$HOST_ROOT/config/config.env" <<'EOF'
TBOX=src/edit/tbox.ttl
ABOX=src/edit/abox.ttl
MAPPINGS=src/edit/mapping.ttl
OBDA=src/edit/ontology.obda
ONTOP_PROPERTIES=src/edit/ontology.properties
CATALOG=src/edit/catalog-v001.xml
QL_PROJECTION_UPDATE=src/sparql/updates/project-ql.ru
PROFILE=qc/profile.txt
ALLOWLIST=qc/allowlist.tsv
EXPECTED=qc/obo-expected.tsv
FAIL_ON=ERROR
QC_STRICT=1
IMPORTS_DIR=src/edit/imports
MAPPINGS_DIR=src/edit/mappings
SERVICES_DIR=src/edit/services
MODULES_DIR=src/edit/modules
ANNOTATIONS_DIR=src/edit/annotations
TEMPLATE_DIRS=src/edit/templates
SHAPES_DIR=src/shapes
SPARQL_CHECKS=src/sparql/checks
SPARQL_REPORTS=src/sparql/reports
ONTOLOGY_DESIGN_RECORD=docs/ontology-design.md
TARGET=build
RELEASES=releases
OUTPUT_FORMAT=ttl
REASONER=structural
REFERENCE_PROFILE=DL
ONTOP_PROFILE=QL
JAVA_CONF=config/java.conf
BASE_IRI=https://example.org/ontology/project/
INSTANCE_BASE_IRI=https://example.org/id/project/
ONTOGPT_MODEL=
ONTOGPT_ALLOW_EXTERNAL_LLM=0
DB_SAMPLE_ROWS=20
DB_SAMPLE_TABLES=
DB_SAMPLE_TO_LLM=0
SHACL_FAIL_ON=VIOLATION
EOF

cat > "$BIN/robot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command="$1"
shift

case "$command" in
  report)
    input=""
    output=""
    profile=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) input="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --profile) profile="$2"; shift 2 ;;
        --fail-on|--catalog) shift 2 ;;
        *) shift ;;
      esac
    done
    iri_control=0
    while IFS=$'\t' read -r severity rule; do
      case "$rule" in
        *example-forbidden_iri.rq)
          iri_control=1
          cp "${rule#file://}" "$ROBOT_CAPTURE_DIR/example-forbidden_iri.rq"
          ;;
      esac
    done < "$profile"
    printf 'report input=%s iri=%s\n' "$input" "$iri_control" >> "$ROBOT_LOG"
    if [ "$iri_control" -eq 1 ] \
        && grep -Fq 'https://foreign.example/BadClass' "$input"; then
      printf '%s\n' $'Level\tRule Name\tSubject\tProperty\tValue' \
        $'ERROR\tnative-example-forbidden_iri\thttps://foreign.example/BadClass\turn:antonia:qc:ENTITY_OUTSIDE_BASE_IRI\tbad namespace' \
        > "$output"
      exit 42
    fi
    printf '%s\n' $'Level\tRule Name\tSubject\tProperty\tValue' > "$output"
    ;;
  merge)
    output=""
    inputs=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) inputs+=("$2"); shift 2 ;;
        --output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf 'merge\n' >> "$ROBOT_LOG"
    : > "$output"
    for input in "${inputs[@]}"; do cat "$input" >> "$output"; done
    ;;
  reason)
    input=""
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) input="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --reasoner|--equivalent-classes-allowed|--exclude-tautologies) shift 2 ;;
        *) shift ;;
      esac
    done
    cp "$input" "$output"
    ;;
  *) exit 43 ;;
esac
EOF
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$BIN/java"
chmod +x "$BIN/robot" "$BIN/java" "$HOST_ROOT/toolbox/reason.sh"

cat > "$HOST_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://example.org/ontology/project/> a owl:Ontology .
<https://example.org/ontology/project/GoodClass> a owl:Class .
EOF
cat > "$HOST_ROOT/src/edit/imports/foreign.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://foreign.example/ontology/> a owl:Ontology .
<https://foreign.example/BadClass> a owl:Class .
EOF
cat > "$HOST_ROOT/src/edit/mapping.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://foreign.example/mapping/> a owl:Ontology .
<https://foreign.example/BadClass> a owl:Class .
EOF

: > "$TEST_ROOT/robot.log"
(
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
    ROBOT_CAPTURE_DIR="$TEST_ROOT/captured" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/import-accepted.log"
)

grep -Eq '^report input=.*/src/edit/tbox\.ttl iri=1$' "$TEST_ROOT/robot.log"
grep -Eq '^report input=.*/src/edit/imports/foreign\.ttl iri=0$' "$TEST_ROOT/robot.log"
if grep '^report ' "$TEST_ROOT/robot.log" | grep -Fq '/mapping.ttl'; then
  echo "Error: configured MAPPINGS was checked for owned IRI policy" >&2
  exit 1
fi
first_report_line="$(grep -n '^report ' "$TEST_ROOT/robot.log" | head -n 1 | cut -d: -f1)"
merge_line="$(grep -n '^merge$' "$TEST_ROOT/robot.log" | cut -d: -f1)"
test "$first_report_line" -lt "$merge_line"
grep -Fq '<https://example.org/ontology/project/>' \
  "$TEST_ROOT/captured/example-forbidden_iri.rq"
grep -Fq '<https://example.org/id/project/>' \
  "$TEST_ROOT/captured/example-forbidden_iri.rq"
if grep -Fq '<urn:antonia:config:' "$TEST_ROOT/captured/example-forbidden_iri.rq"; then
  echo "Error: native IRI query contains an unresolved configuration sentinel" >&2
  exit 1
fi
test -f "$HOST_ROOT/build/classified.ttl"

cat > "$HOST_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://example.org/ontology/project/> a owl:Ontology .
<https://foreign.example/BadClass> a owl:Class .
EOF
: > "$TEST_ROOT/robot.log"
if (
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
    ROBOT_CAPTURE_DIR="$TEST_ROOT/captured" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/local-rejected.log" 2>&1
); then
  echo "Error: example-forbidden_iri accepted an invalid project-owned IRI" >&2
  exit 1
fi
grep -Fq 'native-example-forbidden_iri' "$TEST_ROOT/local-rejected.log"
grep -Fq 'Source: src/edit/tbox.ttl' "$TEST_ROOT/local-rejected.log"
if grep -q '^merge$' "$TEST_ROOT/robot.log"; then
  echo "Error: ontology was merged before owned IRI validation" >&2
  exit 1
fi

# Removing the rule from qc/profile.txt disables it without changing the query
# file or its source-scope assignment in config.env.
printf '%s\n' $'ERROR\texample-forbidden_equivalence\tnon-mapping-source' \
  > "$HOST_ROOT/qc/profile.txt"
: > "$TEST_ROOT/robot.log"
(
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
    ROBOT_CAPTURE_DIR="$TEST_ROOT/captured" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/local-control-disabled.log"
)
grep -Eq '^report input=.*/src/edit/tbox\.ttl iri=0$' "$TEST_ROOT/robot.log"
grep -q '^merge$' "$TEST_ROOT/robot.log"
printf '%s\n' \
  $'ERROR\texample-forbidden_iri\tproject-source' \
  $'ERROR\texample-forbidden_equivalence\tnon-mapping-source' \
  > "$HOST_ROOT/qc/profile.txt"

# Exercise the exact scope with the pinned ROBOT runtime when available: a
# foreign entity declaration in an import is accepted, while the same
# declaration in the project TBox is rejected before merge.
if [ -x "$ROOT/.tools/bin/robot" ] && [ -x "$ROOT/.tools/bin/java" ]; then
  REAL_ROOT="$TEST_ROOT/real-host"
  mkdir -p "$REAL_ROOT/toolbox/checks" "$REAL_ROOT/config" "$REAL_ROOT/qc" \
    "$REAL_ROOT/src/sparql/checks" \
    "$REAL_ROOT/src/edit/imports" "$REAL_ROOT/src/edit/modules" \
    "$REAL_ROOT/src/edit/annotations"
  cp "$ROOT/toolbox/common.sh" "$REAL_ROOT/toolbox/common.sh"
  cp "$ROOT/toolbox/reason.sh" "$REAL_ROOT/toolbox/reason.sh"
  cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$REAL_ROOT/toolbox/checks/"
  cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$REAL_ROOT/toolbox/checks/"
  cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$REAL_ROOT/src/sparql/checks/"
  cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$REAL_ROOT/src/sparql/checks/"
  cp "$HOST_ROOT/config/config.env" "$REAL_ROOT/config/config.env"
  cp "$HOST_ROOT/qc/profile.txt" "$REAL_ROOT/qc/profile.txt"
  cat > "$REAL_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://example.org/ontology/project/> a owl:Ontology .
<https://example.org/ontology/project/GoodClass> a owl:Class .
EOF
  cp "$HOST_ROOT/src/edit/imports/foreign.ttl" \
    "$REAL_ROOT/src/edit/imports/foreign.ttl"
  (
    cd "$REAL_ROOT"
    PATH="$ROOT/.tools/bin:$PATH" SKIP_TEMPLATES=1 ./toolbox/reason.sh \
      > "$TEST_ROOT/real-import-accepted.log"
  )
  test -f "$REAL_ROOT/build/classified.ttl"

  cat > "$REAL_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<https://example.org/ontology/project/> a owl:Ontology .
<https://foreign.example/BadClass> a owl:Class .
EOF
  if (
    cd "$REAL_ROOT"
    PATH="$ROOT/.tools/bin:$PATH" SKIP_TEMPLATES=1 ./toolbox/reason.sh \
      > "$TEST_ROOT/real-local-rejected.log" 2>&1
  ); then
    echo "Error: pinned ROBOT accepted an invalid project-owned IRI" >&2
    exit 1
  fi
  grep -Fq 'ENTITY_OUTSIDE_BASE_IRI' "$TEST_ROOT/real-local-rejected.log"
  echo "native forbidden IRI pre-merge scope: passed"
else
  echo "native forbidden IRI pre-merge scope: skipped (local ROBOT unavailable)"
fi

echo "IRI source scope test: passed"
