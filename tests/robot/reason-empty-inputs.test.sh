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

mkdir -p "$WORK/toolbox/checks" "$WORK/config" "$WORK/qc" \
  "$WORK/src/sparql/checks" "$BIN"
cp "$ROOT/toolbox/common.sh" "$WORK/toolbox/common.sh"
cp "$ROOT/toolbox/reason.sh" "$WORK/toolbox/reason.sh"
cp "$ROOT/toolbox/project_ql.sh" "$WORK/toolbox/project_ql.sh"
cp "$ROOT/toolbox/validate_dl.sh" "$WORK/toolbox/validate_dl.sh"
cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$WORK/toolbox/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$WORK/toolbox/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_equivalence.rq" "$WORK/src/sparql/checks/"
cp "$ROOT/toolbox/checks/example-forbidden_iri.rq" "$WORK/src/sparql/checks/"
printf '%s\n' \
  $'ERROR\texample-forbidden_iri\tproject-source' \
  $'ERROR\texample-forbidden_equivalence\tnon-mapping-source' \
  > "$WORK/qc/profile.txt"

cat > "$WORK/config/config.env" <<'EOF'
TBOX=src/edit/myOntology-tbox.rdf
ABOX=src/edit/myOntology-abox.rdf
MAPPINGS=
OBDA=src/edit/myOntology-tbox.obda
ONTOP_PROPERTIES=src/edit/myOntology.properties
CATALOG=src/edit/catalog-v001.xml
QL_PROJECTION_UPDATE=src/sparql/updates/project-ql.ru
PROFILE=qc/profile.txt
ALLOWLIST=qc/allowlist.tsv
EXPECTED=qc/obo-expected.tsv
FAIL_ON=ERROR
QC_STRICT=1
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
OUTPUT_FORMAT=rdf
REASONER=HERMIT
REFERENCE_PROFILE=DL
ONTOP_PROFILE=QL
JAVA_CONF=config/java.conf
BASE_IRI=https://example.org/ontology/myOntology/
INSTANCE_BASE_IRI=https://example.org/id/myOntology/
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
chmod +x "$BIN/robot" "$BIN/java" "$WORK/toolbox/reason.sh" \
  "$WORK/toolbox/project_ql.sh" "$WORK/toolbox/validate_dl.sh"

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
test ! -e "$WORK/tmp/merged.rdf"
test ! -e "$WORK/tmp/classified.rdf"

# A TBox alone is still a real input and must follow the normal merge/reason
# path even when imports and mappings are absent.
mkdir -p "$WORK/src/edit"
printf '%s\n' '<rdf:RDF/>' > "$WORK/src/edit/myOntology-tbox.rdf"
mkdir -p "$WORK/src/sparql/updates"
printf '%s\n' 'DELETE {} INSERT {} WHERE {}' \
  > "$WORK/src/sparql/updates/project-ql.ru"
: > "$TEST_ROOT/robot.log"
(
  cd "$WORK"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
    ./toolbox/reason.sh
) > "$TEST_ROOT/tbox-only.log" 2>&1

test -f "$WORK/tmp/merged.rdf"
test -f "$WORK/tmp/classified.rdf"
test ! -e "$WORK/tmp/merged.owl"
test ! -e "$WORK/tmp/classified.owl"
test "$(wc -l < "$TEST_ROOT/robot.log" | tr -d ' ')" -eq 3
grep -Fq 'merge --input' "$TEST_ROOT/robot.log"
test "$(grep -c 'report --input' "$TEST_ROOT/robot.log")" -eq 1
test "$(grep -c 'reason --input' "$TEST_ROOT/robot.log")" -eq 1
grep -Fq -- '--equivalent-classes-allowed none' "$TEST_ROOT/robot.log"
if grep -Fq 'no import or files to merge' "$TEST_ROOT/tbox-only.log"; then
  cat "$TEST_ROOT/tbox-only.log" >&2
  exit 1
fi

# OWL 2 DL validation applies directly to the classified reference ontology.
# It must not depend on an undeclared project-specific SPARQL update.
: > "$TEST_ROOT/robot.log"
(
  cd "$WORK"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
    ./toolbox/validate_dl.sh
) > "$TEST_ROOT/validate-dl.log" 2>&1

test -f "$WORK/tmp/dl-profile-validation.txt"
grep -Eq 'validate-profile --input .*/tmp/classified\.rdf' \
  "$TEST_ROOT/robot.log"
if grep -Fq 'query ' "$TEST_ROOT/robot.log"; then
  echo "Error: OWL 2 DL validation transformed the classified ontology" >&2
  exit 1
fi
test ! -e "$WORK/tmp/classified-dl-view.rdf"

# The QL projection must consume the RDF/XML merge artifact produced above;
# this guards against the former merged.ttl/merged.rdf handoff mismatch.
(
  cd "$WORK"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
    ./toolbox/project_ql.sh
) > "$TEST_ROOT/project-ql.log" 2>&1

test -f "$WORK/tmp/ontop-ql.rdf"
test ! -e "$WORK/tmp/ontop-ql.owl"
grep -Eq 'query --input .*/tmp/merged\.rdf' "$TEST_ROOT/robot.log"
if grep -Fq 'running reason.sh' "$TEST_ROOT/project-ql.log"; then
  cat "$TEST_ROOT/project-ql.log" >&2
  exit 1
fi

# The same centralized paths must work for the two other supported formats.
for format in ttl owl; do
  awk -v value="$format" '
    /^OUTPUT_FORMAT=/ { print "OUTPUT_FORMAT=" value; next }
    { print }
  ' "$WORK/config/config.env" > "$WORK/config/config.env.next"
  mv "$WORK/config/config.env.next" "$WORK/config/config.env"
  rm -rf "$WORK/tmp"
  : > "$TEST_ROOT/robot.log"

  (
    cd "$WORK"
    PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" SKIP_TEMPLATES=1 \
      ./toolbox/reason.sh
    PATH="$BIN:$PATH" ROBOT_LOG="$TEST_ROOT/robot.log" \
      ./toolbox/project_ql.sh
  ) > "$TEST_ROOT/$format.log" 2>&1

  test -f "$WORK/tmp/merged.$format"
  test -f "$WORK/tmp/classified.$format"
  test -f "$WORK/tmp/ontop-ql.$format"
  grep -Eq "query --input .*/tmp/merged\\.$format" "$TEST_ROOT/robot.log"
done

echo "reasoning output formats test: passed"
