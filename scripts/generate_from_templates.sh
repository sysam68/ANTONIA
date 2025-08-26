#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# generate_from_templates.sh
# Convert all TSV templates (classes, annotations, individuals) into TTL modules.
# Outputs go to src/edit/modules/, preserving the TSV basename.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

echo "▶ Generating TTL from TSV templates"
generated=0

for DIR in "${TEMPLATE_DIRS[@]}"; do
  [ -d "$DIR" ] || continue
  while read -r TSV; do
    [ -n "${TSV:-}" ] || continue
    OUT="$MODULES_DIR/$(basename "${TSV%.tsv}").ttl"
    echo "  - template: ${TSV#$ROOT/} → ${OUT#$ROOT/}"
    robot template --template "$TSV" --output "$OUT"
    generated=$((generated+1))
  done < <(tsvs_under "$DIR")
done

if [ "$generated" -eq 0 ]; then
  echo "ℹ No TSV templates found in: ${TEMPLATE_DIRS[*]}"
else
  echo "✓ Generated $generated TTL module(s)"
fi

