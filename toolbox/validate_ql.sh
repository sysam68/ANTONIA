#!/usr/bin/env bash
# Validate the operational Ontop projection against OWL 2 QL.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$ONTOP_PROFILE" = "QL" ] || {
  echo "✖ ONTOP_PROFILE must be QL, got: $ONTOP_PROFILE" >&2
  exit 1
}

MERGED="$TARGET/merged.rdf"
QL_PROJECTION="$TARGET/ontop-ql.rdf"
OUTFILE="$TARGET/ql-profile-validation.txt"

if [ ! -f "$QL_PROJECTION" ] \
  || { [ -f "$MERGED" ] && [ "$MERGED" -nt "$QL_PROJECTION" ]; } \
  || [ "$QL_PROJECTION_UPDATE" -nt "$QL_PROJECTION" ]; then
  "$(dirname "$0")/project_ql.sh"
fi

echo "▶ Validating Ontop projection (OWL 2 QL)"
robot validate-profile \
  --input "$QL_PROJECTION" \
  --profile QL \
  --output "$OUTFILE"

echo "✓ OWL 2 QL validation completed: ${OUTFILE#$ROOT/}"
