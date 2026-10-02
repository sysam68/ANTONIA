#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reason.sh
# Build the working ontology and run reasoning with ROBOT.
#
# Steps:
#   1) Generate RDF/XML modules from all TSV templates (classes, annotations, ABox)
#   2) Merge TBox + (optional) ABox + imports + generated modules + annotations
#   3) Classify with the selected reasoner (default: ELK)
#
# Outputs use OUTPUT_FORMAT (rdf, ttl, or owl):
#   - target/merged.<format>
#   - target/classified.<format>
#
# Environment variables:
#   REASONER=hermit|jfact|ELK|structural   (default: ELK)
#   SKIP_TEMPLATES=1                       (skip TSV->RDF/XML generation)
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

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

# 2a) Merge
MERGED_ROBOT_OUTPUT="$(robot_output_path "$MERGED_ONTOLOGY")"
echo "▶ Merging ontologies → ${MERGED_ONTOLOGY#$ROOT/}"
robot merge "${MERGE_INPUTS[@]}" --output "$MERGED_ROBOT_OUTPUT"
finalize_robot_output "$MERGED_ONTOLOGY" "$MERGED_ROBOT_OUTPUT"

# 3) Reason
CLASSIFIED_ROBOT_OUTPUT="$(robot_output_path "$CLASSIFIED_ONTOLOGY")"
echo "▶ Reasoning with ${REASONER} → ${CLASSIFIED_ONTOLOGY#$ROOT/}"
robot reason \
  --input "$MERGED_ONTOLOGY" \
  --reasoner "$REASONER" \
  --equivalent-classes-allowed none \
  --exclude-tautologies structural \
  --output "$CLASSIFIED_ROBOT_OUTPUT"
finalize_robot_output "$CLASSIFIED_ONTOLOGY" "$CLASSIFIED_ROBOT_OUTPUT"

echo "✓ Reasoning complete"
echo "  - Merged:     ${MERGED_ONTOLOGY#$ROOT/}"
echo "  - Classified: ${CLASSIFIED_ONTOLOGY#$ROOT/}"
