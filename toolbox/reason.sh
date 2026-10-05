#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reason.sh
# Build the working ontology and run reasoning with ROBOT.
#
# Steps:
#   1) Generate RDF/XML modules from all TSV templates (classes, annotations, ABox)
#   2) Reject class equivalences in every source except configured MAPPINGS
#   3) Merge TBox + (optional) ABox + mappings + imports + generated modules
#   4) Classify with the selected reasoner (default: ELK)
#
# Outputs use OUTPUT_FORMAT (rdf, ttl, or owl):
#   - TARGET/merged.<format>
#   - TARGET/classified.<format>
#
# Environment variables:
#   REASONER=hermit|jfact|ELK|structural   (default: ELK)
#   SKIP_TEMPLATES=1                       (skip TSV->RDF/XML generation)
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

TOOLBOX_DIR="$(cd "$(dirname "$0")" && pwd -P)"
EQUIVALENCE_CHECK="$TOOLBOX_DIR/checks/forbidden_equivalence.rq"
REASON_RUNTIME_DIR=""

cleanup_reason_runtime() {
  [ -n "$REASON_RUNTIME_DIR" ] || return 0
  case "$REASON_RUNTIME_DIR" in
    */antonia-reason.*) rm -rf -- "$REASON_RUNTIME_DIR" ;;
  esac
}
trap cleanup_reason_runtime EXIT

# 1) TSV -> RDF/XML generation (optional)
if [ "${SKIP_TEMPLATES:-0}" != "1" ]; then
  "$(dirname "$0")/generate_from_templates.sh"
else
  echo "▶ Skipping TSV → RDF/XML generation (SKIP_TEMPLATES=1)"
fi

# 2) Build merge input list from known locations
echo "▶ Building merge input list"
MERGE_INPUTS=()
while IFS= read -r arg; do
  MERGE_INPUTS+=("$arg")
done < <(build_merge_inputs)

# A newly initialized project may not contain ontology sources yet. This is a
# valid no-op; once at least one source exists, the normal merge/reasoning path
# remains mandatory.
if [ "${#MERGE_INPUTS[@]}" -eq 0 ]; then
  echo "ℹ no import or files to merge; skipping reasoning."
  exit 0
fi

# Equivalence assertions are an ontology-alignment concern and are accepted
# only from the configured mapping ontology. Validate every other source
# individually before any merge so the offending source remains identifiable.
# The final reasoning pass accepts asserted mapping equivalences while still
# rejecting equivalences inferred by the selected reasoner.
EQUIVALENCE_POLICY="none"
NON_MAPPING_INPUTS=()
while IFS= read -r arg; do
  NON_MAPPING_INPUTS+=("$arg")
done < <(build_merge_inputs 0)

if [ "${#NON_MAPPING_INPUTS[@]}" -gt 0 ]; then
  if [ ! -f "$EQUIVALENCE_CHECK" ]; then
    echo "✖ Missing native ROBOT control: $EQUIVALENCE_CHECK" >&2
    exit 1
  fi
  REASON_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/antonia-reason.XXXXXX")"
  EQUIVALENCE_PROFILE="$REASON_RUNTIME_DIR/equivalence-profile.txt"
  printf 'ERROR\tfile://%s\n' "$EQUIVALENCE_CHECK" > "$EQUIVALENCE_PROFILE"
  mapping_display="${MAPPINGS#$ROOT/}"
  [ -n "$mapping_display" ] || mapping_display="the configured MAPPINGS ontology"
  echo "▶ Validating source equivalences before merge"
  source_index=1
  input_index=1
  while [ "$input_index" -lt "${#NON_MAPPING_INPUTS[@]}" ]; do
    source_ontology="${NON_MAPPING_INPUTS[$input_index]}"
    source_output="$REASON_RUNTIME_DIR/source-$source_index.tsv"
    source_log="$REASON_RUNTIME_DIR/source-$source_index.log"
    echo "  - ${source_ontology#$ROOT/}"
    report_cmd=( robot report \
      --input "$source_ontology" \
      --profile "$EQUIVALENCE_PROFILE" \
      --fail-on ERROR \
      --output "$source_output" )
    [ -f "$CATALOG" ] && report_cmd+=( --catalog "$CATALOG" )
    if ! "${report_cmd[@]}" > "$source_log" 2>&1; then
      cat "$source_log" >&2
      echo "✖ Class equivalence is forbidden outside $mapping_display." >&2
      echo "  Source: ${source_ontology#$ROOT/}" >&2
      exit 1
    fi
    source_index=$((source_index + 1))
    input_index=$((input_index + 2))
  done
fi

if [ -n "${MAPPINGS:-}" ] && [ -f "$MAPPINGS" ]; then
  EQUIVALENCE_POLICY="asserted-only"
fi

# 2a) Merge
MERGED_ROBOT_OUTPUT="$(robot_output_path "$MERGED_ONTOLOGY")"
echo "▶ Merging ontologies → ${MERGED_ONTOLOGY#$ROOT/}"
robot merge "${MERGE_INPUTS[@]}" --output "$MERGED_ROBOT_OUTPUT"
finalize_robot_output "$MERGED_ONTOLOGY" "$MERGED_ROBOT_OUTPUT"

# 3) Reason
CLASSIFIED_ROBOT_OUTPUT="$(robot_output_path "$CLASSIFIED_ONTOLOGY")"
echo "▶ Reasoning with ${REASONER} → ${CLASSIFIED_ONTOLOGY#$ROOT/}"
echo "  - Equivalent classes allowed: ${EQUIVALENCE_POLICY}"
robot reason \
  --input "$MERGED_ONTOLOGY" \
  --reasoner "$REASONER" \
  --equivalent-classes-allowed "$EQUIVALENCE_POLICY" \
  --exclude-tautologies structural \
  --output "$CLASSIFIED_ROBOT_OUTPUT"
finalize_robot_output "$CLASSIFIED_ONTOLOGY" "$CLASSIFIED_ROBOT_OUTPUT"

echo "✓ Reasoning complete"
echo "  - Merged:     ${MERGED_ONTOLOGY#$ROOT/}"
echo "  - Classified: ${CLASSIFIED_ONTOLOGY#$ROOT/}"
