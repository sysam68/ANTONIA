#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# common.sh
# Loads centralized configuration from config/config.env and exposes
# shared paths/helpers for the ROBOT toolchain.
# Keep this file free of business actions (no generation, no reasoning).
#
# Supports both standalone mode (repo root) and submodule mode (host root).
# -----------------------------------------------------------------------------
set -euo pipefail

# -----------------------------------------------------------------------------
# Resolve project root - supports submodule mode
# -----------------------------------------------------------------------------
# If we're in a submodule named "toolbox", the host repo root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$(dirname "$SCRIPT_DIR")/config" ]; then
  # Submodule mode: toolbox/ is inside host repo, host has config/
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  TOOLBOX_MODE=1
elif [ -d "$SCRIPT_DIR/config" ]; then
  # Standalone mode: we're at repo root
  ROOT="$SCRIPT_DIR"
  TOOLBOX_MODE=0
else
  # Fallback to git root
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  TOOLBOX_MODE=0
fi

# Prefer the repository-local toolchain installed by `make install-robot`.
if [ -x "$ROOT/.tools/bin/robot" ]; then
  PATH="$ROOT/.tools/bin:$PATH"
  export PATH
fi

# -----------------------------------------------------------------------------
# Load config/config.env (single source of truth)
# -----------------------------------------------------------------------------
ENV_FILE="$ROOT/config/config.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "✖ config.env not found at: $ENV_FILE"
  echo "  Run 'bash toolbox/toolbox/init_project.sh' to initialize the project"
  exit 1
fi

# Load key=value pairs into environment
set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

# -----------------------------------------------------------------------------
# Validate the configuration contract. Values, including optional empty values,
# belong exclusively in config/config.env.
# -----------------------------------------------------------------------------
require_config() {
  local name
  for name in "$@"; do
    if ! declare -p "$name" >/dev/null 2>&1; then
      echo "✖ Missing configuration variable in ${ENV_FILE#$ROOT/}: $name" >&2
      return 1
    fi
  done
}

require_config \
  TBOX ABOX MAPPINGS OBDA CATALOG QL_PROJECTION_UPDATE \
  IMPORTS_DIR MODULES_DIR ANNOTATIONS_DIR TEMPLATE_DIRS \
  SHAPES_DIR SPARQL_CHECKS SPARQL_REPORTS TARGET RELEASES \
  REASONER REFERENCE_PROFILE ONTOP_PROFILE JAVA_CONF

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
[ -n "$MAPPINGS" ] && MAPPINGS="$(abspath "$MAPPINGS")"
OBDA="$(abspath "$OBDA")"
CATALOG="$(abspath "$CATALOG")"
QL_PROJECTION_UPDATE="$(abspath "$QL_PROJECTION_UPDATE")"
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

# Optional: load the configured JVM profile if present.
JAVA_CONF_FILE="$(abspath "$JAVA_CONF")"
if [ -f "$JAVA_CONF_FILE" ] && [ "${ONTOLOGY_JAVA_CONF_LOADED:-}" != "$JAVA_CONF_FILE" ]; then
  export JAVA_TOOL_OPTIONS="$(tr '\n' ' ' < "$JAVA_CONF_FILE") ${JAVA_TOOL_OPTIONS:-}"
  export ONTOLOGY_JAVA_CONF_LOADED="$JAVA_CONF_FILE"
fi

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

# List supported ontology files under a directory (non-recursive).
# RDF/XML is the generated format; Turtle remains accepted for external inputs.
ontology_files_under() {
  local d="$1"
  test -d "$d" || return 0
  find "$d" -maxdepth 1 -type f \( -name '*.rdf' -o -name '*.ttl' \) | sort || true
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

  # An ontology-to-ontology mapping is optional and independent from the TBox.
  if [ -n "${MAPPINGS:-}" ] && [ -f "$MAPPINGS" ]; then
    inputs+=( --input "$MAPPINGS" )
  fi

  # Collect additional ontology files
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ontology_files_under "$IMPORTS_DIR")
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ontology_files_under "$MODULES_DIR")
  while read -r f; do [ -n "${f:-}" ] && inputs+=( --input "$f" ); done < <(ontology_files_under "$ANNOT_DIR")

  # Print as lines so caller can read into an array:
  #   readarray -t MERGE_INPUTS < <(build_merge_inputs)
  printf '%s\n' "${inputs[@]}"
}

# Export TOOLBOX_MODE for scripts that need to know
export TOOLBOX_MODE

