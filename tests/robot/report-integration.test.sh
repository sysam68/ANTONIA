#!/usr/bin/env bash
# Verify that ROBOT owns every post-reasoning project SPARQL control. Native IRI
# ownership is a pre-merge source control covered by iri-scope.test.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-report-integration.XXXXXX)"
HOST_ROOT="$TEMP_ROOT/host"
BIN="$TEMP_ROOT/bin"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-report-integration.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$HOST_ROOT/config" "$HOST_ROOT/custom/qc" \
  "$HOST_ROOT/custom/sparql/checks" "$HOST_ROOT/custom/sparql/reports" \
  "$HOST_ROOT/custom/output" "$TEMP_ROOT/captured" "$BIN"
cp -R "$ROOT/toolbox" "$HOST_ROOT/toolbox"
cp "$ROOT/toolbox/templates/config/config.env" "$HOST_ROOT/config/config.env"
cat >> "$HOST_ROOT/config/config.env" <<'EOF'
PROFILE=custom/qc/robot-profile.txt
SPARQL_CHECKS=custom/sparql/checks
SPARQL_REPORTS=custom/sparql/reports
TARGET=custom/output
EOF
printf '%s\n' $'ERROR\tmissing_label' > "$HOST_ROOT/custom/qc/robot-profile.txt"
printf '%s\n' '<rdf:RDF/>' > "$HOST_ROOT/custom/output/classified.rdf"

cat > "$HOST_ROOT/custom/sparql/checks/project_rule.rq" <<'EOF'
SELECT DISTINCT ?entity ?property ?value WHERE {
  BIND(<urn:antonia:config:BASE_IRI> AS ?entity)
  BIND(<urn:antonia:qc:PROJECT_RULE> AS ?property)
  BIND(STR(<urn:antonia:config:INSTANCE_BASE_IRI>) AS ?value)
  FILTER(false)
}
EOF
printf '%s\n' 'SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }' \
  > "$HOST_ROOT/custom/sparql/reports/counts.rq"

cat > "$BIN/robot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$ROBOT_LOG"
command="$1"
shift
case "$command" in
  report)
    output=""
    profile=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --output) output="$2"; shift 2 ;;
        --profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    test -n "$output"
    test -n "$profile"
    cp "$profile" "$ROBOT_CAPTURE_DIR/effective-profile.txt"
    while IFS=$'\t' read -r severity rule; do
      case "$rule" in
        file://*) cp "${rule#file://}" "$ROBOT_CAPTURE_DIR/$(basename "${rule#file://}")" ;;
      esac
    done < "$profile"
    mkdir -p "$(dirname "$output")"
    : > "$output"
    ;;
  query)
    query=""
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --input) shift 2 ;;
        --query) query="$2"; shift 2 ;;
        *) output="$1"; shift ;;
      esac
    done
    case "$query" in
      */checks/*)
        echo "blocking SPARQL check executed outside robot report: $query" >&2
        exit 91
        ;;
    esac
    test -n "$output"
    : > "$output"
    ;;
  *)
    echo "unexpected ROBOT command: $command" >&2
    exit 92
    ;;
esac
EOF
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$BIN/java"
chmod +x "$BIN/robot" "$BIN/java"

: > "$TEMP_ROOT/robot.log"
(
  cd "$HOST_ROOT"
  PATH="$BIN:$PATH" ROBOT_LOG="$TEMP_ROOT/robot.log" \
    ROBOT_CAPTURE_DIR="$TEMP_ROOT/captured" \
    ./toolbox/report.sh > "$TEMP_ROOT/report.log"
)

test "$(grep -c '^report ' "$TEMP_ROOT/robot.log")" -eq 2
test "$(grep -c '^query ' "$TEMP_ROOT/robot.log")" -eq 1
grep -Fq '/custom/sparql/reports/counts.rq' "$TEMP_ROOT/robot.log"
if grep -Fq '/custom/sparql/checks/' "$TEMP_ROOT/robot.log"; then
  echo "Error: a blocking SPARQL control ran through robot query" >&2
  exit 1
fi

EFFECTIVE_PROFILE="$TEMP_ROOT/captured/effective-profile.txt"
grep -Fqx $'ERROR\tmissing_label' "$EFFECTIVE_PROFILE"
grep -Eq $'^ERROR\tfile://.*/antonia-robot-report\.[^/]+/queries/project-project_rule\.rq$' \
  "$EFFECTIVE_PROFILE"
if grep -Fq 'native-forbidden_iri.rq' "$EFFECTIVE_PROFILE"; then
  echo "Error: forbidden_iri was applied to the classified merge" >&2
  exit 1
fi

PROJECT_QUERY="$TEMP_ROOT/captured/project-project_rule.rq"
grep -Fq '<https://example.org/ontology/myOntology/>' "$PROJECT_QUERY"
grep -Fq '<https://example.org/id/myOntology/>' "$PROJECT_QUERY"
if grep -Fq '<urn:antonia:config:' "$PROJECT_QUERY"; then
  echo "Error: an ANTONIA configuration sentinel was not rendered" >&2
  exit 1
fi
test ! -e "$HOST_ROOT/custom/output/robot-profile.txt"
test ! -e "$HOST_ROOT/custom/output/robot-report-queries"
test -f "$HOST_ROOT/custom/output/qc_report.tsv"
test -f "$HOST_ROOT/custom/output/qc_report.html"
test -f "$HOST_ROOT/custom/output/reports/counts.tsv"
grep -Fq 'Profile: custom/qc/robot-profile.txt' "$TEMP_ROOT/report.log"
grep -Fq 'Project checks: custom/sparql/checks' "$TEMP_ROOT/report.log"
grep -Fq 'No SHACL shapes found' "$TEMP_ROOT/report.log"

echo "ROBOT report integration test: passed"
