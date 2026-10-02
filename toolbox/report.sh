#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# report.sh
# Generate QC outputs for the classified ontology using ROBOT and optional
# SHACL validation.
#
# Steps:
#   1) Ensure a classified ontology exists (runs reason.sh if needed)
#   2) Render native and project SPARQL controls into a ROBOT profile
#   3) Run `robot report` to produce the canonical QC TSV and HTML
#   4) Run SHACL over the classified graph when shapes exist
#   5) Run SPARQL analytics (non-blocking summaries → target/reports/*.tsv)
#
# Environment variables:
#   FAIL_ON=ERROR|WARN|NONE   (default: ERROR)  -> passed to `robot report`
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

FAIL_ON="${FAIL_ON:-ERROR}"
TOOLBOX_DIR="$(cd "$(dirname "$0")" && pwd -P)"
NATIVE_CHECKS_DIR="$TOOLBOX_DIR/checks"

validate_config_iri() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ] \
      || ! printf '%s\n' "$value" | grep -Eq '^[A-Za-z][A-Za-z0-9+.-]*:.+'; then
    echo "✖ $name must be a non-empty absolute IRI in ${ENV_FILE#$ROOT/}." >&2
    return 1
  fi

  case "$value" in
    *' '*|*$'\t'*|*$'\n'*|*$'\r'*|*'<'*|*'>'*|*'"'*|*'{'*|*'}'*|*'|'*|*'^'*|*'`'*|*'\'*)
      echo "✖ $name contains a character forbidden in a SPARQL IRI: $value" >&2
      return 1
      ;;
  esac
}

render_robot_query() {
  local source="$1"
  local destination="$2"

  awk -v base_iri="$BASE_IRI" -v instance_base_iri="$INSTANCE_BASE_IRI" '
    function replace_all(text, token, value, position) {
      while ((position = index(text, token)) > 0) {
        text = substr(text, 1, position - 1) value substr(text, position + length(token))
      }
      return text
    }
    {
      line = replace_all($0, "<urn:antonia:config:BASE_IRI>", "<" base_iri ">")
      line = replace_all(line, "<urn:antonia:config:INSTANCE_BASE_IRI>", "<" instance_base_iri ">")
      print line
    }
  ' "$source" > "$destination"

  if grep -Fq '<urn:antonia:config:' "$destination"; then
    echo "✖ Unresolved ANTONIA configuration sentinel in: $source" >&2
    return 1
  fi
}

append_robot_check() {
  local source="$1"
  local rendered_name="$2"
  local destination="$ROBOT_QUERY_DIR/$rendered_name"

  render_robot_query "$source" "$destination"
  printf 'ERROR\tfile://%s\n' "$destination" >> "$ROBOT_PROFILE"
}

# -----------------------------------------------------------------------------
# 1) Ensure classified ontology is available
# -----------------------------------------------------------------------------
if [ ! -f "$CLASSIFIED_ONTOLOGY" ]; then
  echo "▶ No classified ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
else
  echo "▶ Using existing classified ontology: ${CLASSIFIED_ONTOLOGY#$ROOT/}"
fi

mkdir -p "$TARGET"

# -----------------------------------------------------------------------------
# 2) Effective ROBOT profile: built-in rules plus all blocking SPARQL controls
# -----------------------------------------------------------------------------
if ! declare -p BASE_IRI >/dev/null 2>&1 \
    || ! declare -p INSTANCE_BASE_IRI >/dev/null 2>&1; then
  echo "✖ BASE_IRI and INSTANCE_BASE_IRI are required in ${ENV_FILE#$ROOT/}." >&2
  exit 1
fi
validate_config_iri BASE_IRI "$BASE_IRI"
validate_config_iri INSTANCE_BASE_IRI "$INSTANCE_BASE_IRI"

ROBOT_QUERY_DIR="$TARGET/robot-report-queries"
ROBOT_PROFILE="$TARGET/robot-profile.txt"
mkdir -p "$ROBOT_QUERY_DIR"
for stale_query in "$ROBOT_QUERY_DIR"/*.rq; do
  [ -f "$stale_query" ] && rm -f -- "$stale_query"
done
: > "$ROBOT_PROFILE"

if [ -n "${PROFILE:-}" ] && [ -f "$PROFILE" ]; then
  cat "$PROFILE" > "$ROBOT_PROFILE"
  if [ -s "$ROBOT_PROFILE" ] && [ -n "$(tail -c 1 "$ROBOT_PROFILE")" ]; then
    printf '\n' >> "$ROBOT_PROFILE"
  fi
fi

if [ ! -f "$NATIVE_CHECKS_DIR/forbidden_iri.rq" ]; then
  echo "✖ Missing native ROBOT control: $NATIVE_CHECKS_DIR/forbidden_iri.rq" >&2
  exit 1
fi
append_robot_check \
  "$NATIVE_CHECKS_DIR/forbidden_iri.rq" \
  "native-forbidden_iri.rq"

if [ -d "$SPARQL_CHECKS" ]; then
  for rq in "$SPARQL_CHECKS"/*.rq; do
    [ -f "$rq" ] || continue
    append_robot_check "$rq" "project-$(basename "$rq")"
  done
fi

echo "▶ ROBOT controls → ${ROBOT_PROFILE#$ROOT/}"

# -----------------------------------------------------------------------------
# 3) ROBOT report (canonical QC gate) TSV + HTML
# -----------------------------------------------------------------------------
QC_TSV="$TARGET/qc_report.tsv"
QC_HTML="$TARGET/qc_report.html"
echo "▶ ROBOT report → ${QC_TSV#$ROOT/} (fail-on: ${FAIL_ON})"

# Build commands with the rendered profile and optional allowlist/expected.
cmd=( robot report --input "$CLASSIFIED_ONTOLOGY" --output "$QC_TSV" --fail-on "$FAIL_ON" --profile "$ROBOT_PROFILE" )

# If you set these in config/config.env, they will be absolute via common.sh
# ALLOWLIST=qc/allowlist.tsv
# EXPECTED=qc/obolo-expected.tsv
[ -n "${ALLOWLIST:-}" ] && [ -s "$ALLOWLIST" ] && cmd+=( --allowlist "$ALLOWLIST" )
[ -n "${EXPECTED:-}" ]  && [ -s "$EXPECTED" ]  && cmd+=( --expected "$EXPECTED" )

robot_failed=0
if ! "${cmd[@]}"; then
  robot_failed=1
fi

# HTML version of the same report
cmd_html=( robot report --input "$CLASSIFIED_ONTOLOGY" --output "$QC_HTML" --fail-on "$FAIL_ON" --profile "$ROBOT_PROFILE" )

[ -n "${ALLOWLIST:-}" ] && [ -s "$ALLOWLIST" ] && cmd_html+=( --allowlist "$ALLOWLIST" )
[ -n "${EXPECTED:-}" ]  && [ -s "$EXPECTED" ]  && cmd_html+=( --expected "$EXPECTED" )

if ! "${cmd_html[@]}"; then
  robot_failed=1
fi

echo "  - HTML: ${QC_HTML#$ROOT/}"

# -----------------------------------------------------------------------------
# 4) External SHACL validation, only when SHACL shapes exist
# -----------------------------------------------------------------------------
shacl_failed=0
if [ -d "$SHAPES_DIR" ] \
    && find "$SHAPES_DIR" -type f \
      \( -name '*.ttl' -o -name '*.rdf' -o -name '*.owl' \) -print -quit \
      | grep -q .; then
  SEMANTIC_PYTHON="$ROOT/.tools/semantic/bin/python"
  if [ ! -x "$SEMANTIC_PYTHON" ]; then
    echo "✖ SHACL shapes are configured but pySHACL is not installed." >&2
    echo "  Run: make install-semantic-tools" >&2
    shacl_failed=1
  else
    echo "▶ Running SHACL validation (fail-on: ${SHACL_FAIL_ON})"
    if ! "$SEMANTIC_PYTHON" "$TOOLBOX_DIR/validate_shacl.py" \
        --data "$CLASSIFIED_ONTOLOGY" \
        --shapes-dir "$SHAPES_DIR" \
        --report-rdf "$TARGET/shacl_report.ttl" \
        --report-text "$TARGET/shacl_report.txt" \
        --fail-on "$SHACL_FAIL_ON"; then
      echo "✖ SHACL validation failed (see ${TARGET#$ROOT/}/shacl_report.txt)" >&2
      shacl_failed=1
    fi
  fi
else
  echo "ℹ No SHACL shapes found under: ${SHAPES_DIR#$ROOT/}"
fi

# -----------------------------------------------------------------------------
# 5) SPARQL analytics (non-blocking outputs, not quality-control gates)
# -----------------------------------------------------------------------------
if [ -d "$SPARQL_REPORTS" ]; then
  echo "▶ Running SPARQL reports"
  mkdir -p "$TARGET/reports"
  for rq in "$SPARQL_REPORTS"/*.rq; do
    [ -f "$rq" ] || continue
    out="$TARGET/reports/$(basename "${rq%.rq}").tsv"
    echo "  - $(basename "$rq") → ${out#$ROOT/}"
    robot query --input "$CLASSIFIED_ONTOLOGY" --query "$rq" "$out"
  done
else
  echo "ℹ No SPARQL reports directory found: ${SPARQL_REPORTS#$ROOT/}"
fi

# -----------------------------------------------------------------------------
# 6) Final status after every configured control has run
# -----------------------------------------------------------------------------
if [ "$robot_failed" -ne 0 ] || [ "$shacl_failed" -ne 0 ]; then
  [ "$robot_failed" -eq 0 ] \
    || echo "✖ ROBOT quality controls failed (see ${QC_TSV#$ROOT/} and ${QC_HTML#$ROOT/})." >&2
  [ "$shacl_failed" -eq 0 ] \
    || echo "✖ External SHACL validation failed." >&2
  exit 1
fi

echo "✓ QC completed successfully"
echo "  - QC report:   ${QC_TSV#$ROOT/}"
echo "  - QC HTML report:  ${QC_HTML#$ROOT/}"
echo "  - SHACL report: ${TARGET#$ROOT/}/shacl_report.txt (if shapes exist)"
echo "  - Reports dir: ${TARGET#$ROOT/}/reports (if any)"
