#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# project_ql.sh
# Derive the conservative OWL 2 QL ontology used by Ontop from the configured
# merged ontology serialization.
# The expressive OWL 2 DL reference ontology remains unchanged.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [ ! -f "$MERGED_ONTOLOGY" ]; then
  echo "▶ No merged ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
fi

[ -f "$QL_PROJECTION_UPDATE" ] || {
  echo "✖ QL projection update not found: ${QL_PROJECTION_UPDATE#$ROOT/}" >&2
  exit 1
}

QL_ROBOT_OUTPUT="$(robot_output_path "$ONTOP_QL_ONTOLOGY")"
echo "▶ Deriving OWL 2 QL projection → ${ONTOP_QL_ONTOLOGY#$ROOT/}"
robot query \
  --input "$MERGED_ONTOLOGY" \
  --update "$QL_PROJECTION_UPDATE" \
  --output "$QL_ROBOT_OUTPUT"
finalize_robot_output "$ONTOP_QL_ONTOLOGY" "$QL_ROBOT_OUTPUT"

echo "✓ Ontop projection generated: ${ONTOP_QL_ONTOLOGY#$ROOT/}"
