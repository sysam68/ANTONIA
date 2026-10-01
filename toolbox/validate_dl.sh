#!/usr/bin/env bash
# Validate the expressive reference ontology against OWL 2 DL.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$REFERENCE_PROFILE" = "DL" ] || {
  echo "✖ REFERENCE_PROFILE must be DL, got: $REFERENCE_PROFILE" >&2
  exit 1
}

CLASSIFIED="$TARGET/classified.rdf"
DL_VIEW="$TARGET/classified-dl-view.rdf"
DL_VIEW_OWL="$TARGET/classified-dl-view.owl"
OUTFILE="$TARGET/dl-profile-validation.txt"

if [ ! -f "$CLASSIFIED" ]; then
  echo "▶ No classified RDF ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
fi

robot query \
  --input "$CLASSIFIED" \
  --update "$ROOT/src/sparql/updates/fix-dl-profile.ru" \
  --output "$DL_VIEW_OWL"
cp -f "$DL_VIEW_OWL" "$DL_VIEW"
rm -f "$DL_VIEW_OWL"

echo "▶ Validating expressive reference ontology (OWL 2 DL)"
robot validate-profile \
  --input "$DL_VIEW" \
  --profile DL \
  --output "$OUTFILE"

echo "✓ OWL 2 DL validation completed: ${OUTFILE#$ROOT/}"
