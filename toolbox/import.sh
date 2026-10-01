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

# --- Portable temp dir helper (macOS/GNU) ---
make_temp_dir() {
  # Try macOS-style: -t <prefix> with pattern
  if d="$(mktemp -d -t import.XXXXXX 2>/dev/null)"; then
    printf '%s\n' "$d"; return
  fi
  # Try GNU-style with explicit template
  if d="$(mktemp -d "${TMPDIR:-/tmp}/import.XXXXXX" 2>/dev/null)"; then
    printf '%s\n' "$d"; return
  fi
  # Last resort: manual
  d="${TMPDIR:-/tmp}/import.$$.${RANDOM}"
  mkdir -p "$d" || return 1
  printf '%s\n' "$d"
}
# --------------------------------------------

# Paths
# Resolve ROOT using common.sh logic (supports released toolbox mode)
source "$(dirname "$0")/common.sh"

CONF_FILE="$ROOT/config/import.env"
DEST_DIR="$IMPORTS_DIR"

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

  # Detect mode:
  if [[ "$URL" == *"#"* ]]; then
    MODE="GIT"
    REPO_URL="${URL%%#*}"
    FILE_PATH="${URL#*#}"
    # REF requis en GIT mode
    [ -n "$REF" ] && [ "$REF" != "-" ] || { echo "✖ Line $lineno: missing REF (branch/tag) for GIT mode" >&2; exit 1; }
    # Extension from file path
    SRC_EXT="${FILE_PATH##*.}"
    echo "→ [$lineno] GIT: $REPO_URL@$REF:$FILE_PATH  → ${LOCAL_NAME}.${SRC_EXT}"
  else
    MODE="RAW"
    RAW_URL="$URL"
    # Extension from URL (best effort)
    SRC_EXT="${URL##*.}"
    echo "→ [$lineno] RAW: $RAW_URL  → ${LOCAL_NAME}.${SRC_EXT}"
  fi

  DEST_FILE="$DEST_DIR/${LOCAL_NAME}.${SRC_EXT}"

  if [ "$MODE" = "RAW" ]; then
    # Download
    curl -fsSL "$RAW_URL" -o "$DEST_FILE"
    echo "  ✓ Fetched → ${DEST_FILE#$ROOT/}"

  else
    # GIT sparse checkout into a temp dir
    WORKDIR="$(make_temp_dir)" || { echo "✖ Line $lineno: cannot create temp dir" >&2; exit 1; }
    (
      set -e
      cd "$WORKDIR"
      git init -q
      git remote add origin "$REPO_URL"

      git fetch --depth 1 origin "refs/heads/$REF:refs/remotes/origin/$REF" 2>/dev/null \
      || git fetch --depth 1 origin "refs/tags/$REF:refs/tags/$REF" 2>/dev/null \
      || git fetch --depth 1 origin "$REF"

      git checkout -q --detach FETCH_HEAD

      PATH_DIR="$(dirname "$FILE_PATH")"
      git sparse-checkout init --cone >/dev/null 2>&1 || true
      git sparse-checkout set "$PATH_DIR" >/dev/null 2>&1 || true
      git sparse-checkout reapply >/dev/null 2>&1 || true

      [ -f "$FILE_PATH" ] || { echo "✖ Line $lineno: file not found in repo: $FILE_PATH" >&2; exit 1; }

      mkdir -p "$(dirname "$DEST_FILE")"
      cp -f "$FILE_PATH" "$DEST_FILE"
    )
    rm -rf "$WORKDIR" || true
    echo "  ✓ Pulled → ${DEST_FILE#$ROOT/}"
  fi
done < "$CONF_FILE"

echo "✓ All imports updated in ${DEST_DIR#$ROOT/}"
