#!/usr/bin/env bash
# Run OntoGPT with ANTONIA consent and output-location guards.
set -euo pipefail
source "$(dirname "$0")/common.sh"

usage() {
  echo "Usage: run_ontogpt.sh [--contains-db-samples] <input.txt> <output.yaml> [template.yaml]" >&2
}

CONTAINS_DB_SAMPLES=0
if [ "${1:-}" = "--contains-db-samples" ]; then
  CONTAINS_DB_SAMPLES=1
  shift
fi

INPUT="${1:-}"
OUTPUT="${2:-}"
TEMPLATE="${3:-}"
[ -n "$INPUT" ] && [ -n "$OUTPUT" ] || { usage; exit 2; }
[ -f "$INPUT" ] || { echo "Error: normalized input not found: $INPUT" >&2; exit 1; }

if [ -z "$TEMPLATE" ]; then
  TEMPLATE="$ROOT/.agents/skills/antonia-ontologist/assets/antonia_ontology_candidates.yaml"
  if [ ! -f "$TEMPLATE" ]; then
    TEMPLATE="$(dirname "$0")/.agents/skills/antonia-ontologist/assets/antonia_ontology_candidates.yaml"
  fi
fi
[ -f "$TEMPLATE" ] || { echo "Error: OntoGPT template not found" >&2; exit 1; }
[ -n "$ONTOGPT_MODEL" ] || { echo "Error: ONTOGPT_MODEL must be configured" >&2; exit 1; }

case "$ONTOGPT_MODEL" in
  ollama/*) ;;
  *)
    [ "$ONTOGPT_ALLOW_EXTERNAL_LLM" = "1" ] || {
      echo "Error: external LLM processing is not authorized" >&2
      echo "Set ONTOGPT_ALLOW_EXTERNAL_LLM=1 after reviewing the source and provider." >&2
      exit 1
    }
    ;;
esac

if [ "$CONTAINS_DB_SAMPLES" -eq 1 ] && [ "$DB_SAMPLE_TO_LLM" != "1" ]; then
  echo "Error: transmission of database samples to the LLM is not authorized" >&2
  exit 1
fi

case "$OUTPUT" in
  /*) OUTPUT_ABS="$OUTPUT" ;;
  *) OUTPUT_ABS="$ROOT/$OUTPUT" ;;
esac
SEMANTIC_PYTHON="$ROOT/.tools/semantic/bin/python"
[ -x "$SEMANTIC_PYTHON" ] || {
  echo "Error: OntoGPT is not installed; run make install-semantic-tools" >&2
  exit 1
}
OUTPUT_ABS="$("$SEMANTIC_PYTHON" -c \
  'import os, sys; print(os.path.realpath(sys.argv[1]))' "$OUTPUT_ABS")"
TARGET_REAL="$("$SEMANTIC_PYTHON" -c \
  'import os, sys; print(os.path.realpath(sys.argv[1]))' "$TARGET")"
case "$OUTPUT_ABS" in
  "$TARGET_REAL"/*) ;;
  *) echo "Error: OntoGPT output must be written under ${TARGET#$ROOT/}/" >&2; exit 1 ;;
esac

command -v ontogpt >/dev/null 2>&1 || {
  echo "Error: OntoGPT is not installed; run make install-semantic-tools" >&2
  exit 1
}

mkdir -p "$(dirname "$OUTPUT_ABS")"
ontogpt extract \
  --inputfile "$INPUT" \
  --template "$TEMPLATE" \
  --model "$ONTOGPT_MODEL" \
  --output "$OUTPUT_ABS" \
  --output-format yaml \
  --cut-input-text

"$SEMANTIC_PYTHON" "$(dirname "$0")/validate_ontogpt_output.py" \
  "$OUTPUT_ABS"
