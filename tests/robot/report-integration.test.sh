#!/usr/bin/env bash
# Verify that ROBOT owns every SPARQL control and that native IRI sentinels are
# rendered from project configuration. SHACL remains optional and external.

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

mkdir -p "$HOST_ROOT/config" "$HOST_ROOT/qc" "$HOST_ROOT/tmp" \
  "$HOST_ROOT/src/sparql/checks" "$HOST_ROOT/src/sparql/reports" "$BIN"
cp -R "$ROOT/toolbox" "$HOST_ROOT/toolbox"
cp "$ROOT/toolbox/templates/config/config.env" "$HOST_ROOT/config/config.env"
printf '%s\n' $'ERROR\tmissing_label' > "$HOST_ROOT/qc/profile.txt"
printf '%s\n' '<rdf:RDF/>' > "$HOST_ROOT/tmp/classified.rdf"

cat > "$HOST_ROOT/src/sparql/checks/project_rule.rq" <<'EOF'
SELECT DISTINCT ?entity ?property ?value WHERE {
  BIND(<urn:antonia:config:BASE_IRI> AS ?entity)
  BIND(<urn:antonia:qc:PROJECT_RULE> AS ?property)
  BIND(STR(<urn:antonia:config:INSTANCE_BASE_IRI>) AS ?value)
  FILTER(false)
}
EOF
printf '%s\n' 'SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }' \
  > "$HOST_ROOT/src/sparql/reports/counts.rq"

cat > "$BIN/robot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$ROBOT_LOG"
command="$1"
shift
case "$command" in
  report)
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    test -n "$output"
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
    ./toolbox/report.sh > "$TEMP_ROOT/report.log"
)

test "$(grep -c '^report ' "$TEMP_ROOT/robot.log")" -eq 2
test "$(grep -c '^query ' "$TEMP_ROOT/robot.log")" -eq 1
grep -Fq '/src/sparql/reports/counts.rq' "$TEMP_ROOT/robot.log"
if grep -Fq '/src/sparql/checks/' "$TEMP_ROOT/robot.log"; then
  echo "Error: a blocking SPARQL control ran through robot query" >&2
  exit 1
fi

EFFECTIVE_PROFILE="$HOST_ROOT/tmp/robot-profile.txt"
grep -Fqx $'ERROR\tmissing_label' "$EFFECTIVE_PROFILE"
grep -Eq $'^ERROR\tfile://.*/tmp/robot-report-queries/native-forbidden_iri\.rq$' \
  "$EFFECTIVE_PROFILE"
grep -Eq $'^ERROR\tfile://.*/tmp/robot-report-queries/project-project_rule\.rq$' \
  "$EFFECTIVE_PROFILE"

NATIVE_QUERY="$HOST_ROOT/tmp/robot-report-queries/native-forbidden_iri.rq"
PROJECT_QUERY="$HOST_ROOT/tmp/robot-report-queries/project-project_rule.rq"
grep -Fq 'SELECT DISTINCT ?entity ?property ?value' "$NATIVE_QUERY"
grep -Fq '<https://example.org/ontology/myOntology/>' "$NATIVE_QUERY"
grep -Fq '<https://example.org/id/myOntology/>' "$NATIVE_QUERY"
grep -Fq '<https://example.org/ontology/myOntology/>' "$PROJECT_QUERY"
grep -Fq '<https://example.org/id/myOntology/>' "$PROJECT_QUERY"
if grep -Fq '<urn:antonia:config:' "$NATIVE_QUERY" "$PROJECT_QUERY"; then
  echo "Error: an ANTONIA configuration sentinel was not rendered" >&2
  exit 1
fi
test ! -e "$HOST_ROOT/tmp/checks"
grep -Fq 'No SHACL shapes found' "$TEMP_ROOT/report.log"

# Exercise the native query with the pinned local ROBOT when it is available.
if [ -x "$ROOT/.tools/bin/robot" ] && [ -x "$ROOT/.tools/bin/java" ]; then
  REAL_ROOT="$TEMP_ROOT/real-host"
  mkdir -p "$REAL_ROOT/config" "$REAL_ROOT/qc" "$REAL_ROOT/tmp"
  cp -R "$ROOT/toolbox" "$REAL_ROOT/toolbox"
  cp "$ROOT/toolbox/templates/config/config.env" "$REAL_ROOT/config/config.env"
  : > "$REAL_ROOT/qc/profile.txt"

  cat > "$REAL_ROOT/tmp/classified.rdf" <<'EOF'
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:owl="http://www.w3.org/2002/07/owl#">
  <owl:Class rdf:about="https://example.org/ontology/myOntology/GoodClass"/>
  <owl:NamedIndividual rdf:about="https://example.org/id/myOntology/good"/>
</rdf:RDF>
EOF
  (
    cd "$REAL_ROOT"
    PATH="$ROOT/.tools/bin:$PATH" ./toolbox/report.sh \
      > "$TEMP_ROOT/real-conforming.log"
  )

  cat > "$REAL_ROOT/tmp/classified.rdf" <<'EOF'
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:owl="http://www.w3.org/2002/07/owl#">
  <owl:Class rdf:about="https://foreign.example/BadClass"/>
  <owl:Class rdf:about="https://example.org/ontology/myOntology/v2/VersionedClass"/>
  <owl:NamedIndividual rdf:about="https://example.org/ontology/myOntology/bad-individual"/>
</rdf:RDF>
EOF
  if (
    cd "$REAL_ROOT"
    PATH="$ROOT/.tools/bin:$PATH" ./toolbox/report.sh \
      > "$TEMP_ROOT/real-nonconforming.log" 2>&1
  ); then
    echo "Error: native forbidden_iri control accepted invalid IRIs" >&2
    exit 1
  fi
  grep -Fq 'ENTITY_OUTSIDE_BASE_IRI' "$REAL_ROOT/tmp/qc_report.tsv"
  grep -Fq 'VERSIONED_ENTITY_IRI' "$REAL_ROOT/tmp/qc_report.tsv"
  grep -Fq 'INSTANCE_OUTSIDE_INSTANCE_BASE_IRI' "$REAL_ROOT/tmp/qc_report.tsv"
  echo "native forbidden IRI ROBOT query: passed"
else
  echo "native forbidden IRI ROBOT query: skipped (local ROBOT unavailable)"
fi

echo "ROBOT report integration test: passed"
