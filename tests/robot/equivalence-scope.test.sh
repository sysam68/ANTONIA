#!/usr/bin/env bash
# Verify that class equivalences are accepted only from configured MAPPINGS and
# that every other source is checked before the merge starts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/antonia-equivalence-scope.XXXXXX")"
HOST_ROOT="$TEST_ROOT/host"
BIN="$TEST_ROOT/bin"

cleanup() {
  case "$TEST_ROOT" in
    "${TMPDIR:-/tmp}"/antonia-equivalence-scope.*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$HOST_ROOT/toolbox/checks" "$HOST_ROOT/config" "$HOST_ROOT/src/edit" \
  "$HOST_ROOT/src/edit/imports" "$HOST_ROOT/src/edit/modules" \
  "$HOST_ROOT/src/edit/annotations" "$BIN"
cp "$ROOT/toolbox/common.sh" "$HOST_ROOT/toolbox/common.sh"
cp "$ROOT/toolbox/reason.sh" "$HOST_ROOT/toolbox/reason.sh"
cp "$ROOT/toolbox/checks/forbidden_equivalence.rq" "$HOST_ROOT/toolbox/checks/"

cat > "$HOST_ROOT/config/config.env" <<'EOF'
TBOX=src/edit/tbox.ttl
ABOX=src/edit/abox.ttl
MAPPINGS=src/edit/mapping.ttl
OBDA=src/edit/ontology.obda
ONTOP_PROPERTIES=src/edit/ontology.properties
CATALOG=src/edit/catalog-v001.xml
QL_PROJECTION_UPDATE=src/sparql/updates/project-ql.ru
IMPORTS_DIR=src/edit/imports
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
printf '%s %s\n' "$command" "$*" >> "$ROBOT_LOG"

case "$command" in
  report)
    input=""
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) input="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --profile|--fail-on) shift 2 ;;
        *) shift ;;
      esac
    done
    if grep -Fq 'owl:equivalentClass' "$input"; then
      echo "Class equivalence is forbidden: $input" >&2
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
    : > "$output"
    for input in "${inputs[@]}"; do
      cat "$input" >> "$output"
    done
    ;;
  reason)
    input=""
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) input="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --equivalent-classes-allowed) shift 2 ;;
        *) shift ;;
      esac
    done
    cp "$input" "$output"
    ;;
  *)
    echo "Unexpected ROBOT command: $command" >&2
    exit 43
    ;;
esac
EOF
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$BIN/java"
chmod +x "$BIN/robot" "$BIN/java" "$HOST_ROOT/toolbox/reason.sh"

cat > "$HOST_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://example.org/ontology/> .
ex:ontology a owl:Ontology .
ex:A a owl:Class .
ex:B a owl:Class .
EOF
cat > "$HOST_ROOT/src/edit/mapping.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://example.org/ontology/> .
<https://example.org/mapping/> a owl:Ontology .
ex:A owl:equivalentClass ex:B .
EOF

: > "$TEST_ROOT/robot.log"
(
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/mapping-allowed.log"
)

first_control_line="$(grep -n '^report ' "$TEST_ROOT/robot.log" | head -n 1 | cut -d: -f1)"
first_merge_line="$(grep -n '^merge ' "$TEST_ROOT/robot.log" | head -n 1 | cut -d: -f1)"
test "$first_control_line" -lt "$first_merge_line"
test "$(grep -c '^report ' "$TEST_ROOT/robot.log")" -eq 1
test "$(grep -c -- '--equivalent-classes-allowed asserted-only' "$TEST_ROOT/robot.log")" -eq 1
if grep '^report ' "$TEST_ROOT/robot.log" | grep -Fq '/mapping.ttl'; then
  echo "Error: configured MAPPINGS was checked as a forbidden source" >&2
  exit 1
fi
grep -Fq 'Equivalent classes allowed: asserted-only' "$TEST_ROOT/mapping-allowed.log"
test -f "$HOST_ROOT/build/classified.ttl"

cat > "$HOST_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://example.org/ontology/> .
ex:ontology a owl:Ontology .
ex:A a owl:Class ; owl:equivalentClass ex:B .
ex:B a owl:Class .
EOF
: > "$TEST_ROOT/robot.log"
if (
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/tbox-forbidden.log" 2>&1
); then
  echo "Error: an equivalence outside MAPPINGS was accepted" >&2
  exit 1
fi
grep -Fq 'Class equivalence is forbidden' "$TEST_ROOT/tbox-forbidden.log"
if grep -q '^merge ' "$TEST_ROOT/robot.log"; then
  echo "Error: sources were merged before equivalence validation" >&2
  exit 1
fi

cat > "$HOST_ROOT/src/edit/tbox.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://example.org/ontology/> .
ex:ontology a owl:Ontology .
ex:A a owl:Class .
EOF
cat > "$HOST_ROOT/src/edit/imports/foreign.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://foreign.example/ontology/> .
ex:ontology a owl:Ontology .
ex:A a owl:Class ; owl:equivalentClass ex:B .
ex:B a owl:Class .
EOF
: > "$TEST_ROOT/robot.log"
if (
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh > "$TEST_ROOT/import-forbidden.log" 2>&1
); then
  echo "Error: an equivalence in an import source was accepted" >&2
  exit 1
fi
grep -Fq 'Source: src/edit/imports/foreign.ttl' "$TEST_ROOT/import-forbidden.log"
if grep -q '^merge ' "$TEST_ROOT/robot.log"; then
  echo "Error: sources were merged before imported equivalence validation" >&2
  exit 1
fi

# Confirm the pinned ROBOT report detects an asserted equivalence to an
# anonymous restriction, which --equivalent-classes-allowed none misses.
if [ -x "$ROOT/.tools/bin/robot" ] && [ -x "$ROOT/.tools/bin/java" ]; then
  cat > "$TEST_ROOT/anonymous-equivalence.ttl" <<'EOF'
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix ex: <https://example.org/ontology/> .
ex:ontology a owl:Ontology .
ex:A a owl:Class ;
  owl:equivalentClass [
    a owl:Restriction ;
    owl:onProperty ex:p ;
    owl:someValuesFrom ex:B
  ] .
ex:B a owl:Class .
ex:p a owl:ObjectProperty .
EOF
  printf 'ERROR\tfile://%s\n' "$ROOT/toolbox/checks/forbidden_equivalence.rq" \
    > "$TEST_ROOT/equivalence-profile.txt"
  if PATH="$ROOT/.tools/bin:$PATH" "$ROOT/.tools/bin/robot" report \
      --input "$TEST_ROOT/anonymous-equivalence.ttl" \
      --profile "$TEST_ROOT/equivalence-profile.txt" \
      --fail-on ERROR \
      --output "$TEST_ROOT/real-report.tsv" > "$TEST_ROOT/real-report.log" 2>&1; then
    echo "Error: pinned ROBOT report accepted an anonymous class equivalence" >&2
    exit 1
  fi
  PATH="$ROOT/.tools/bin:$PATH" "$ROOT/.tools/bin/robot" reason \
    --input "$TEST_ROOT/anonymous-equivalence.ttl" \
    --reasoner structural \
    --equivalent-classes-allowed asserted-only \
    --output "$TEST_ROOT/asserted-only.owl" > "$TEST_ROOT/real-asserted.log" 2>&1
fi

echo "equivalence scope test: passed"
