#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# report.sh
# Generate QC outputs for the (classified) ontology using ROBOT and SPARQL.
#
# Steps:
#   1) Ensure a classified ontology exists (runs reason.sh if needed)
#   2) Run `robot report` to produce a QC TSV (fails on ERROR by default)
#   3) Run SHACL over the classified graph
#   4) Run SPARQL "reports" (non-blocking summaries → target/reports/*.tsv)
#   5) Run SPARQL "checks" (must be empty; any result triggers failure)
#
# Environment variables:
#   FAIL_ON=ERROR|WARN|NONE   (default: ERROR)  -> passed to `robot report`
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

FAIL_ON="${FAIL_ON:-ERROR}"

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
# 2) ROBOT report (main QC gate) TSV + HTML
# -----------------------------------------------------------------------------
QC_TSV="$TARGET/qc_report.tsv"
QC_HTML="$TARGET/qc_report.html"
echo "▶ ROBOT report → ${QC_TSV#$ROOT/} (fail-on: ${FAIL_ON})"

# Build command with optional profile/allowlist/expected from config.env
cmd=( robot report --input "$CLASSIFIED_ONTOLOGY" --output "$QC_TSV" --fail-on "$FAIL_ON" )

# If you set these in config/config.env, they will be absolute via common.sh
# PROFILE=qc/profile.txt
# ALLOWLIST=qc/allowlist.tsv
# EXPECTED=qc/obolo-expected.tsv
[ -n "${PROFILE:-}" ]   && [ -f "$PROFILE" ]   && cmd+=( --profile "$PROFILE" )
[ -n "${ALLOWLIST:-}" ] && [ -s "$ALLOWLIST" ] && cmd+=( --allowlist "$ALLOWLIST" )
[ -n "${EXPECTED:-}" ]  && [ -s "$EXPECTED" ]  && cmd+=( --expected "$EXPECTED" )

"${cmd[@]}" || { echo "✖ QC report failed (see ${QC_TSV#$ROOT/})"; exit 1; }

# HTML version of the same report
# Build command with optional profile/allowlist/expected from config.env
cmd_html=( robot report --input "$CLASSIFIED_ONTOLOGY" --output "$QC_HTML" --fail-on "$FAIL_ON" )

[ -n "${PROFILE:-}" ]   && [ -f "$PROFILE" ]   && cmd_html+=( --profile "$PROFILE" )
[ -n "${ALLOWLIST:-}" ] && [ -s "$ALLOWLIST" ] && cmd_html+=( --allowlist "$ALLOWLIST" )
[ -n "${EXPECTED:-}" ]  && [ -s "$EXPECTED" ]  && cmd_html+=( --expected "$EXPECTED" )

"${cmd_html[@]}" || { echo "✖ QC HTML report failed (see ${QC_HTML#$ROOT/})"; exit 1; }

echo "  - HTML: ${QC_HTML#$ROOT/}"

# -----------------------------------------------------------------------------
# 3) SHACL validation
# -----------------------------------------------------------------------------
if [ -d "$SHAPES_DIR" ] \
    && find "$SHAPES_DIR" -type f \
      \( -name '*.ttl' -o -name '*.rdf' -o -name '*.owl' \) -print -quit \
      | grep -q .; then
  SEMANTIC_PYTHON="$ROOT/.tools/semantic/bin/python"
  if [ ! -x "$SEMANTIC_PYTHON" ]; then
    echo "✖ SHACL shapes are configured but pySHACL is not installed." >&2
    echo "  Run: make install-semantic-tools" >&2
    exit 1
  fi
  echo "▶ Running SHACL validation (fail-on: ${SHACL_FAIL_ON})"
  "$SEMANTIC_PYTHON" "$(dirname "$0")/validate_shacl.py" \
    --data "$CLASSIFIED_ONTOLOGY" \
    --shapes-dir "$SHAPES_DIR" \
    --report-rdf "$TARGET/shacl_report.ttl" \
    --report-text "$TARGET/shacl_report.txt" \
    --fail-on "$SHACL_FAIL_ON" || {
      echo "✖ SHACL validation failed (see ${TARGET#$ROOT/}/shacl_report.txt)" >&2
      exit 1
    }
else
  echo "ℹ No SHACL shapes found under: ${SHAPES_DIR#$ROOT/}"
fi

# -----------------------------------------------------------------------------
# 4) SPARQL "reports" (non-blocking analytics)
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
# 5) SPARQL "checks" (blocking: must return empty result sets)
# -----------------------------------------------------------------------------
violations=0
if [ -d "$SPARQL_CHECKS" ]; then
  echo "▶ Running SPARQL checks (must be empty)"
  mkdir -p "$TARGET/checks"
  for rq in "$SPARQL_CHECKS"/*.rq; do
    [ -f "$rq" ] || continue
    out="$TARGET/checks/$(basename "${rq%.rq}").tsv"
    robot query --input "$CLASSIFIED_ONTOLOGY" --query "$rq" "$out"
    if [ -s "$out" ]; then
      echo "✖ Check failed: $(basename "$rq") → non-empty results in ${out#$ROOT/}"
      violations=$((violations+1))
    else
      echo "  ✓ Check passed: $(basename "$rq")"
    fi
  done
else
  echo "ℹ No SPARQL checks directory found: ${SPARQL_CHECKS#$ROOT/}"
fi

# -----------------------------------------------------------------------------
# 6) Final status
# -----------------------------------------------------------------------------
if [ "$violations" -gt 0 ]; then
  echo "✖ $violations SPARQL check(s) failed."
  exit 1
fi

echo "✓ QC completed successfully"
echo "  - QC report:   ${QC_TSV#$ROOT/}"
echo "  - QC HTML report:  ${QC_HTML#$ROOT/}"
echo "  - SHACL report: ${TARGET#$ROOT/}/shacl_report.txt (if shapes exist)"
echo "  - Reports dir: ${TARGET#$ROOT/}/reports (if any)"
echo "  - Checks dir:  ${TARGET#$ROOT/}/checks  (if any)"
