#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reason.sh
# Build the working ontology and run reasoning with ROBOT.
#
# Steps:
#   1) Generate TTL modules from all TSV templates (classes, annotations, ABox)
#   2) Merge TBox + (optional) ABox + imports + generated modules + annotations
#   3) Classify with the selected reasoner (default: ELK)
#
# Outputs:
#   - target/merged.ttl
#   - target/classified.ttl
#
# Environment variables:
#   REASONER=hermit|jfact|ELK|structural   (default: ELK)
#   SKIP_TEMPLATES=1                       (skip TSV->TTL generation)
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

# 1) TSV -> TTL generation (optional)
if [ "${SKIP_TEMPLATES:-0}" != "1" ]; then
  "$(dirname "$0")/generate_from_templates.sh"
else
  echo "▶ Skipping TSV → TTL generation (SKIP_TEMPLATES=1)"
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
MERGED="$TARGET/merged.ttl"
echo "▶ Merging ontologies → ${MERGED#$ROOT/}"
robot merge "${MERGE_INPUTS[@]}" --output "$MERGED"

# 3) Reason
CLASSIFIED="$TARGET/classified.ttl"
echo "▶ Reasoning with ${REASONER} → ${CLASSIFIED#$ROOT/}"
robot reason \
  --input "$MERGED" \
  --reasoner "$REASONER" \
  --equivalent-classes-allowed none \
  --exclude-tautologies structural \
  --output "$CLASSIFIED"

echo "✓ Reasoning complete"
echo "  - Merged:     ${MERGED#$ROOT/}"
echo "  - Classified: ${CLASSIFIED#$ROOT/}"
