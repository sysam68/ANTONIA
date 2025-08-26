#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# common.sh
# Loads centralized configuration from config/config.env and exposes
# shared paths/helpers for the ROBOT toolchain.
# Keep this file free of business actions (no generation, no reasoning).
# -----------------------------------------------------------------------------
set -euo pipefail

# Project root (works from any subdirectory within the repo)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# -----------------------------------------------------------------------------
# Load config/config.env (single source of truth)
# -----------------------------------------------------------------------------
ENV_FILE="$ROOT/config/config.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "✖ config.env not found at: $ENV_FILE"
  exit 1
fi

# Load key=value pairs into environment
set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

# -----------------------------------------------------------------------------
# Defaults (in case some variables are missing in config.env)
# -----------------------------------------------------------------------------
: "${TBOX:=src/edit/ontology-tbox.ttl}"
: "${ABOX:=src/edit/ontology-abox.ttl}"
: "${IMPORTS_DIR:=src/edit/imports}"
: "${MODULES_DIR:=src/edit/modules}"
: "${ANNOTATIONS_DIR:=src/edit/annotations}"

# Comma-separated template directories (no spaces)
: "${TEMPLATE_DIRS:=src/edit/templates,src/edit/templates/instances,src/edit/annotations}"

: "${SHAPES_DIR:=src/shapes}"
: "${SPARQL_CHECKS:=src/sparql/checks}"
: "${SPARQL_REPORTS:=src/sparql/reports}"

: "${TARGET:=target}"
: "${RELEASES:=releases}"

# Build parameters
: "${REASONER:=ELK}"    # ELK | hermit | jfact | structural | ...
: "${OWL_PROFILE:=EL}"  # EL | RL | QL | DL

# -----------------------------------------------------------------------------
# Resolve relative paths against $ROOT
# -----------------------------------------------------------------------------
abspath() {  # usage: abspath <relative-or-absolute>
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s\n' "$ROOT/$1" ;;
  esac
}

TBOX="$(abspath "$TBOX")"
ABOX="$(abspath "$ABOX")"
IMPORTS_DIR="$(abspath "$IMPORTS_DIR")"
MODULES_DIR="$(abspath "$MODULES_DIR")"
ANNOT_DIR="$(abspath "$ANNOTATIONS_DIR")"
SHAPES_DIR="$(abspath "$SHAPES_DIR")"
SPARQL_CHECKS="$(abspath "$SPARQL_CHECKS")"
SPARQL_REPORTS="$(abspath "$SPARQL_REPORTS")"
TARGET="$(abspath "$TARGET")"
RELEASES="$(abspath "$RELEASES")"

# TEMPLATE_DIRS (CSV) → Bash array of absolute paths
IFS=',' read -r -a _TEMPLATE_DIRS_CSV <<< "$TEMPLATE_DIRS"
declare -a TEMPLATE_DIRS_ABS=()
for d in "${_TEMPLATE_DIRS_CSV[@]}"; do
  # trim potential surrounding spaces just in case
  d="${d#"${d%%[! ]*}"}"; d="${d%"${d##*[! ]}"}"
  [ -z "$d" ] && continue
  TEMPLATE_DIRS_ABS+=( "$(abspath "$d")" )
done

# -----------------------------------------------------------------------------
# Tooling prerequisites
# -----------------------------------------------------------------------------
command -v robot >/dev/null 2>&1 || { echo "✖ 'robot' not found in PATH"; exit 1; }
command -v java  >/dev/null 2>&1 || { echo "✖ 'java' not found in PATH"; exit 1; }

# Ensure key directories exist
mkdir -p "$TARGET" "$MODULES_DIR"

# -----------------------------------------------------------------------------
# Helpers (pure functions)
# -----------------------------------------------------------------------------

# Return latest release directory (by natural sort) or non-zero if none
latest_release_dir() {
  test -d "$RELEASES" || return 1
  ls -1 "$RELEASES" 2>/dev/null | sort -V | tail -n1 | awk -v r="$RELEASES" 'NF{print r"/"$0}'
}

# List .ttl files (one per line) under a directory (non-recursive). No output if dir missing.
ttls_under() {
  local d="$1"
  test -d "$d" || return 0
  find "$d" -maxdepth 1 -type f -name '*.ttl' | sort || true
}

# List .tsv files (one per line) under a directory (non-recursive). No output if dir missing.
tsvs_under() {
  local d="$1"
  test -d "$d" || return 0
  find "$d" -maxdepth 1 -type f -name '*.tsv' | sort || true
}

# Build a flat array of '--input <file>' arguments for 'robot merge'
# Includes: TBOX (required), ABOX (optional), and all TTLs from IMPORTS/MODULES/ANNOT_DIR.
build_merge_inputs() {
  local inputs=()

  # TBox is mandatory
  if [ -f "$TBOX" ]; then
    inputs+=( --input "$TBOX" )
  else
    echo "✖ Missing TBox: $TBOX" >&2
    return 1
  fi

  # ABox is optional
  [ -f "$ABOX" ] && inputs+=( --input "$ABOX" )

  # Collect additional TTLs
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ttls_under "$IMPORTS_DIR")
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ttls_under "$MODULES_DIR")
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ttls_under "$ANNOT_DIR")

  # Print as lines so caller can read into an array:
  #   readarray -t MERGE_INPUTS < <(build_merge_inputs)
  printf '%s\n' "${inputs[@]}"
}

