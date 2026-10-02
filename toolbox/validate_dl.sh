#!/usr/bin/env bash
# Validate the expressive reference ontology against OWL 2 DL.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$REFERENCE_PROFILE" = "DL" ] || {
  echo "✖ REFERENCE_PROFILE must be DL, got: $REFERENCE_PROFILE" >&2
  exit 1
}

OUTFILE="$TARGET/dl-profile-validation.txt"

if [ ! -f "$CLASSIFIED_ONTOLOGY" ]; then
  echo "▶ No classified ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
fi

DL_ROBOT_OUTPUT="$(robot_output_path "$DL_VIEW_ONTOLOGY")"
robot query \
  --input "$CLASSIFIED_ONTOLOGY" \
  --update "$ROOT/src/sparql/updates/fix-dl-profile.ru" \
  --output "$DL_ROBOT_OUTPUT"
finalize_robot_output "$DL_VIEW_ONTOLOGY" "$DL_ROBOT_OUTPUT"

echo "▶ Validating expressive reference ontology (OWL 2 DL)"
robot validate-profile \
  --input "$DL_VIEW_ONTOLOGY" \
  --profile DL \
  --output "$OUTFILE"

echo "✓ OWL 2 DL validation completed: ${OUTFILE#$ROOT/}"
