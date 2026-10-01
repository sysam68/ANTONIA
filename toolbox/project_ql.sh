#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# project_ql.sh
# Derive the conservative OWL 2 QL ontology used by Ontop from merged.rdf.
# The expressive OWL 2 DL reference ontology remains unchanged.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

MERGED="$TARGET/merged.rdf"
QL_PROJECTION="$TARGET/ontop-ql.rdf"
QL_PROJECTION_OWL="$TARGET/ontop-ql.owl"

if [ ! -f "$MERGED" ]; then
  echo "▶ No merged RDF ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
fi

[ -f "$QL_PROJECTION_UPDATE" ] || {
  echo "✖ QL projection update not found: ${QL_PROJECTION_UPDATE#$ROOT/}" >&2
  exit 1
}

echo "▶ Deriving OWL 2 QL projection → ${QL_PROJECTION#$ROOT/}"
robot query \
  --input "$MERGED" \
  --update "$QL_PROJECTION_UPDATE" \
  --output "$QL_PROJECTION_OWL"
cp -f "$QL_PROJECTION_OWL" "$QL_PROJECTION"
rm -f "$QL_PROJECTION_OWL"

echo "✓ Ontop projection generated: ${QL_PROJECTION#$ROOT/}"
