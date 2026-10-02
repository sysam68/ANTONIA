#!/usr/bin/env bash
# Verify that an ontology project with no source files is a valid reason no-op.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/antonia-reason-empty-test.XXXXXX")"
WORK="$TEST_ROOT/work"
BIN="$TEST_ROOT/bin"

cleanup() {
  case "$TEST_ROOT" in
    "${TMPDIR:-/tmp}"/antonia-reason-empty-test.*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$WORK/toolbox" "$WORK/config" "$BIN"
cp "$ROOT/toolbox/common.sh" "$WORK/toolbox/common.sh"
cp "$ROOT/toolbox/reason.sh" "$WORK/toolbox/reason.sh"

cat > "$WORK/config/config.env" <<'EOF'
TBOX=src/edit/myOntology-tbox.rdf
ABOX=src/edit/myOntology-abox.rdf
MAPPINGS=
OBDA=src/edit/myOntology-tbox.obda
ONTOP_PROPERTIES=src/edit/myOntology.properties
CATALOG=src/edit/catalog-v001.xml
QL_PROJECTION_UPDATE=src/sparql/updates/project-ql.ru
IMPORTS_DIR=src/edit/imports
MODULES_DIR=src/edit/modules
ANNOTATIONS_DIR=src/edit/annotations
TEMPLATE_DIRS=src/edit/templates,src/edit/templates/instances,src/edit/annotations
SHAPES_DIR=src/shapes
SPARQL_CHECKS=src/sparql/checks
SPARQL_REPORTS=src/sparql/reports
ONTOLOGY_DESIGN_RECORD=docs/ontology-design.md
TARGET=tmp
RELEASES=releases
REASONER=HERMIT
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
if [ "${FAIL_IF_CALLED:-0}" = "1" ]; then
  echo "robot must not run without ontology inputs" >&2
  exit 99
fi
printf '%s\n' "$*" >> "$ROBOT_LOG"
input=""
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --input) input="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$input" "$output"
EOF
cat > "$BIN/java" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN/robot" "$BIN/java" "$WORK/toolbox/reason.sh"

(
  cd "$WORK"
  PATH="$BIN:$PATH" FAIL_IF_CALLED=1 SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh
) > "$TEST_ROOT/reason.log" 2>&1

grep -Fqx 'ℹ no import or files to merge; skipping reasoning.' \
  "$TEST_ROOT/reason.log"
if grep -Fq 'unbound variable' "$TEST_ROOT/reason.log"; then
  cat "$TEST_ROOT/reason.log" >&2
  exit 1
fi
test ! -e "$WORK/tmp/merged.ttl"
test ! -e "$WORK/tmp/classified.ttl"

# A TBox alone is still a real input and must follow the normal merge/reason
# path even when imports and mappings are absent.
mkdir -p "$WORK/src/edit"
printf '%s\n' '<rdf:RDF/>' > "$WORK/src/edit/myOntology-tbox.rdf"
: > "$TEST_ROOT/robot.log"
(
  cd "$WORK"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh
) > "$TEST_ROOT/tbox-only.log" 2>&1

test -f "$WORK/tmp/merged.ttl"
test -f "$WORK/tmp/classified.ttl"
test "$(wc -l < "$TEST_ROOT/robot.log" | tr -d ' ')" -eq 2
grep -Fq 'merge --input' "$TEST_ROOT/robot.log"
grep -Fq 'reason --input' "$TEST_ROOT/robot.log"
if grep -Fq 'no import or files to merge' "$TEST_ROOT/tbox-only.log"; then
  cat "$TEST_ROOT/tbox-only.log" >&2
  exit 1
fi

echo "empty reasoning inputs test: passed"
