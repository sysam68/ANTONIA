#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# import.sh
# Pull/import ontology files into src/import/ from a config file (conf/import.env)
#
# conf/import.env is a TSV with 3 columns per line:
#   1) GIT URL with path after '#', or a RAW direct URL (http/https)
#   2) ref (branch/tag), or '-' for RAW
#   3) local base name (without extension)
#
# Examples (GIT mode):
#   https://github.com/opengroup/archimate-owl.git#dist/archimate.ttl    v3.2.0    archimate
#
# Examples (RAW mode):
#   https://raw.githubusercontent.com/opengroup/archimate-owl/v3.2.0/dist/archimate.ttl  -  archimate
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONF_FILE="$ROOT/conf/import.env"
DEST_DIR="$ROOT/src/import"

# Tools required
command -v git  >/dev/null 2>&1 || { echo "✖ 'git' not found in PATH" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "✖ 'curl' not found in PATH" >&2; exit 1; }

mkdir -p "$DEST_DIR"
[ -f "$CONF_FILE" ] || { echo "✖ Config not found: ${CONF_FILE#$ROOT/}"; exit 1; }

# Trim helper
trim() { awk '{$1=$1;print}'; }

# Read TSV lines
echo "▶ Reading config: ${CONF_FILE#$ROOT/}"
lineno=0
while IFS=$'\t' read -r URL REF LOCAL_NAME || [ -n "${URL:-}" ]; do
  lineno=$((lineno+1))
  # Skip comments and blank lines
  [ -z "${URL:-}" ] && continue
  case "$URL" in \#*|";"* ) continue ;; esac

  URL="$(printf '%s' "$URL" | trim)"
  REF="${REF:-"-"}"; REF="$(printf '%s' "$REF" | trim)"
  LOCAL_NAME="$(printf '%s' "${LOCAL_NAME:-}" | trim)"

  if [ -z "$URL" ] || [ -z "$LOCAL_NAME" ]; then
    echo "✖ Line $lineno: missing required fields (URL and LOCAL_NAME)" >&2
    exit 1
  fi

  # Detect mode
  if [[ "$URL" =~ ^https?:// ]] && [[ "$URL" =~ \.(ttl|owl|rdf|jsonld)$ ]]; then
    MODE="RAW"
    RAW_URL="$URL"
    SRC_EXT="${URL##*.}"   # extension from URL
    REPO_URL=""
    FILE_PATH=""
    echo "→ [$lineno] RAW: $RAW_URL  → ${LOCAL_NAME}.${SRC_EXT}"

  else
    MODE="GIT"
    # Split REPO and PATH using '#'
    if [[ "$URL" != *"#"* ]]; then
      echo "✖ Line $lineno: GIT mode requires '#<path/to/file>' in URL (got: $URL)" >&2
      exit 1
    fi
    REPO_URL="${URL%%#*}"
    FILE_PATH="${URL#*#}"   # path inside repo
    [ -n "$REF" ] && [ "$REF" != "-" ] || { echo "✖ Line $lineno: missing REF (branch/tag) for GIT mode" >&2; exit 1; }
    # Extension from file path
    SRC_EXT="${FILE_PATH##*.}"
    echo "→ [$lineno] GIT: $REPO_URL@$REF:$FILE_PATH  → ${LOCAL_NAME}.${SRC_EXT}"
  fi

  DEST_FILE="$DEST_DIR/${LOCAL_NAME}.${SRC_EXT}"

  if [ "$MODE" = "RAW" ]; then
    # Download
    curl -fsSL "$RAW_URL" -o "$DEST_FILE"
    echo "  ✓ Fetched → ${DEST_FILE#$ROOT/}"

  else
    # GIT sparse checkout into a temp dir
    TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/import.XXXXXX")"
    (
      set -e
      cd "$TMPDIR"
      # Shallow clone without checkout
      git init -q
      git remote add origin "$REPO_URL"
      git fetch --depth 1 origin "$REF"
      git checkout -q -b import "$REF"

      # Enable sparse-checkout to fetch only the file
      git sparse-checkout init --cone >/dev/null 2>&1 || true
      git sparse-checkout set "$FILE_PATH" >/dev/null 2>&1 || true
      # Ensure file exists
      [ -f "$FILE_PATH" ] || { echo "✖ Line $lineno: file not found in repo: $FILE_PATH" >&2; exit 1; }

      # Copy preserving original extension
      mkdir -p "$(dirname "$DEST_FILE")"
      cp -f "$FILE_PATH" "$DEST_FILE"
    )
    rm -rf "$TMPDIR" || true
    echo "  ✓ Pulled → ${DEST_FILE#$ROOT/}"
  fi

done < "$CONF_FILE"

echo "✓ All imports updated in ${DEST_DIR#$ROOT/}"