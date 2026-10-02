#!/usr/bin/env bash
# Validate the operational Ontop projection against OWL 2 QL.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$ONTOP_PROFILE" = "QL" ] || {
  echo "✖ ONTOP_PROFILE must be QL, got: $ONTOP_PROFILE" >&2
  exit 1
}

OUTFILE="$TARGET/ql-profile-validation.txt"

if [ ! -f "$ONTOP_QL_ONTOLOGY" ] \
  || { [ -f "$MERGED_ONTOLOGY" ] && [ "$MERGED_ONTOLOGY" -nt "$ONTOP_QL_ONTOLOGY" ]; } \
  || [ "$QL_PROJECTION_UPDATE" -nt "$ONTOP_QL_ONTOLOGY" ]; then
  "$(dirname "$0")/project_ql.sh"
fi

echo "▶ Validating Ontop projection (OWL 2 QL)"
robot validate-profile \
  --input "$ONTOP_QL_ONTOLOGY" \
  --profile QL \
  --output "$OUTFILE"

echo "✓ OWL 2 QL validation completed: ${OUTFILE#$ROOT/}"
