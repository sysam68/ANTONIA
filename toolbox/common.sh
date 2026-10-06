#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# common.sh
# Loads centralized configuration from config/config.env and exposes
# shared paths/helpers for the ROBOT toolchain.
# Keep this file free of business actions (no generation, no reasoning).
#
# Supports both standalone development and released toolbox installation.
# -----------------------------------------------------------------------------
set -euo pipefail

# -----------------------------------------------------------------------------
# Resolve project root.
# -----------------------------------------------------------------------------
# If installed as "toolbox", the host repository root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$(dirname "$SCRIPT_DIR")/config" ]; then
  # Released toolbox mode: toolbox/ is inside the configured host repository.
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

# Prefer repository-local tools installed by ANTONIA.
if [ -d "$ROOT/.tools/bin" ]; then
  PATH="$ROOT/.tools/bin:$PATH"
  export PATH
fi

# -----------------------------------------------------------------------------
# Load config/config.env (single source of truth)
# -----------------------------------------------------------------------------
ENV_FILE="$ROOT/config/config.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "✖ config.env not found at: $ENV_FILE"
  echo "  Run 'bash toolbox/init_project.sh' to initialize the project"
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
  TBOX ABOX MAPPINGS OBDA ONTOP_PROPERTIES CATALOG QL_PROJECTION_UPDATE \
  PROFILE ALLOWLIST EXPECTED FAIL_ON QC_STRICT \
  IMPORTS_DIR MODULES_DIR ANNOTATIONS_DIR TEMPLATE_DIRS \
  SHAPES_DIR SPARQL_CHECKS SPARQL_REPORTS ONTOLOGY_DESIGN_RECORD \
  TARGET RELEASES OUTPUT_FORMAT REASONER REFERENCE_PROFILE ONTOP_PROFILE JAVA_CONF \
  ONTOGPT_MODEL ONTOGPT_ALLOW_EXTERNAL_LLM DB_SAMPLE_ROWS \
  DB_SAMPLE_TABLES DB_SAMPLE_TO_LLM SHACL_FAIL_ON

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
ONTOP_PROPERTIES="$(abspath "$ONTOP_PROPERTIES")"
CATALOG="$(abspath "$CATALOG")"
QL_PROJECTION_UPDATE="$(abspath "$QL_PROJECTION_UPDATE")"
PROFILE="$(abspath "$PROFILE")"
ALLOWLIST="$(abspath "$ALLOWLIST")"
EXPECTED="$(abspath "$EXPECTED")"
IMPORTS_DIR="$(abspath "$IMPORTS_DIR")"
MODULES_DIR="$(abspath "$MODULES_DIR")"
ANNOT_DIR="$(abspath "$ANNOTATIONS_DIR")"
SHAPES_DIR="$(abspath "$SHAPES_DIR")"
SPARQL_CHECKS="$(abspath "$SPARQL_CHECKS")"
SPARQL_REPORTS="$(abspath "$SPARQL_REPORTS")"
ONTOLOGY_DESIGN_RECORD="$(abspath "$ONTOLOGY_DESIGN_RECORD")"
TARGET="$(abspath "$TARGET")"
RELEASES="$(abspath "$RELEASES")"

case "$OUTPUT_FORMAT" in
  rdf|ttl|owl) : ;;
  *)
    echo "✖ OUTPUT_FORMAT must be rdf, ttl, or owl; got: $OUTPUT_FORMAT" >&2
    exit 1
    ;;
esac

case "$FAIL_ON" in
  NONE|INFO|WARN|ERROR) : ;;
  *)
    echo "✖ FAIL_ON must be NONE, INFO, WARN, or ERROR; got: $FAIL_ON" >&2
    exit 1
    ;;
esac

validate_control_name() {
  case "$1" in
    ''|.*|*/*|*..*|*[!A-Za-z0-9_-]*)
      echo "✖ Invalid SPARQL control name in ${ENV_FILE#$ROOT/}: $1" >&2
      return 1
      ;;
  esac
}

control_query_path() {
  validate_control_name "$1"
  printf '%s/%s.rq\n' "$SPARQL_CHECKS" "$1"
}

validate_control_scope() {
  case "$1" in
    ''|post-reason|project-source|non-mapping-source) : ;;
    *)
      echo "✖ Invalid ROBOT control scope in ${PROFILE#$ROOT/}: $1" >&2
      echo "  Expected: post-reason, project-source, or non-mapping-source" >&2
      return 1
      ;;
  esac
}

# Canonical build artifacts. Runtime scripts consume these variables instead
# of reconstructing filenames independently, so a format change applies to the
# complete pipeline.
ontology_output_path() {
  printf '%s/%s.%s\n' "$TARGET" "$1" "$OUTPUT_FORMAT"
}

MERGED_ONTOLOGY="$(ontology_output_path merged)"
CLASSIFIED_ONTOLOGY="$(ontology_output_path classified)"
ONTOP_QL_ONTOLOGY="$(ontology_output_path ontop-ql)"
DL_VIEW_ONTOLOGY="$(ontology_output_path classified-dl-view)"

# Validate the configured ontology namespaces before interpolating them into a
# SPARQL query. These helpers are shared by pre-merge source controls and the
# post-reasoning report controls.
validate_config_iri() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ] \
      || ! printf '%s\n' "$value" | grep -Eq '^[A-Za-z][A-Za-z0-9+.-]*:.+'; then
    echo "✖ $name must be a non-empty absolute IRI in ${ENV_FILE#$ROOT/}." >&2
    return 1
  fi

  case "$value" in
    *' '*|*$'\t'*|*$'\n'*|*$'\r'*|*'<'*|*'>'*|*'"'*|*'{'*|*'}'*|*'|'*|*'^'*|*'`'*|*'\'*)
      echo "✖ $name contains a character forbidden in a SPARQL IRI: $value" >&2
      return 1
      ;;
  esac
}

render_robot_query() {
  local source="$1"
  local destination="$2"

  if ! declare -p BASE_IRI >/dev/null 2>&1 \
      || ! declare -p INSTANCE_BASE_IRI >/dev/null 2>&1; then
    echo "✖ BASE_IRI and INSTANCE_BASE_IRI are required in ${ENV_FILE#$ROOT/}." >&2
    return 1
  fi
  validate_config_iri BASE_IRI "$BASE_IRI"
  validate_config_iri INSTANCE_BASE_IRI "$INSTANCE_BASE_IRI"

  awk -v base_iri="$BASE_IRI" -v instance_base_iri="$INSTANCE_BASE_IRI" '
    function replace_all(text, token, value, position) {
      while ((position = index(text, token)) > 0) {
        text = substr(text, 1, position - 1) value substr(text, position + length(token))
      }
      return text
    }
    {
      line = replace_all($0, "<urn:antonia:config:BASE_IRI>", "<" base_iri ">")
      line = replace_all(line, "<urn:antonia:config:INSTANCE_BASE_IRI>", "<" instance_base_iri ">")
      print line
    }
  ' "$source" > "$destination"

  if grep -Fq '<urn:antonia:config:' "$destination"; then
    echo "✖ Unresolved ANTONIA configuration sentinel in: $source" >&2
    return 1
  fi
}

# ROBOT infers serialization from the output extension but does not recognize
# .rdf. For RDF/XML delivery, write .owl first and copy the bytes to .rdf.
robot_output_path() {
  case "$OUTPUT_FORMAT" in
    rdf) printf '%s.owl\n' "${1%.*}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

finalize_robot_output() {
  local final_path="$1"
  local robot_path="$2"
  if [ "$robot_path" != "$final_path" ]; then
    cp -f "$robot_path" "$final_path"
    rm -f "$robot_path"
  fi
}

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

# List the ontology sources owned by the host project. Imported ontologies and
# the alignment ontology configured by MAPPINGS are deliberately excluded:
# their entity IRIs are owned by their publishers, not by this project.
project_source_files() {
  [ -f "$TBOX" ] && printf '%s\n' "$TBOX"
  [ -f "$ABOX" ] && printf '%s\n' "$ABOX"
  ontology_files_under "$MODULES_DIR"
  ontology_files_under "$ANNOT_DIR"
}

# Build a flat array of '--input <file>' arguments for 'robot merge'.
# Includes the TBox, ABox, and mapping ontology when their configured files
# exist, plus all supported files from IMPORTS/MODULES/ANNOT_DIR. Pass 0 to
# exclude the configured mapping ontology for source-scope validation.
build_merge_inputs() {
  local include_mapping="${1:-1}"
  local inputs=()

  case "$include_mapping" in
    0|1) ;;
    *) echo "Error: build_merge_inputs expects 0 or 1" >&2; return 2 ;;
  esac

  # A newly initialized project may not have ontology sources yet.
  [ -f "$TBOX" ] && inputs+=( --input "$TBOX" )

  # ABox is optional
  [ -f "$ABOX" ] && inputs+=( --input "$ABOX" )

  # An ontology-to-ontology mapping is optional and independent from the TBox.
  if [ "$include_mapping" -eq 1 ] \
      && [ -n "${MAPPINGS:-}" ] && [ -f "$MAPPINGS" ]; then
    inputs+=( --input "$MAPPINGS" )
  fi

  # Collect additional ontology files
  while read -r f; do
    [ -n "${f:-}" ] || continue
    [ "$include_mapping" -eq 0 ] && [ -n "${MAPPINGS:-}" ] \
      && [ "$f" = "$MAPPINGS" ] && continue
    inputs+=( --input "$f" )
  done < <(ontology_files_under "$IMPORTS_DIR")
  while read -r f; do
    [ -n "${f:-}" ] || continue
    [ "$include_mapping" -eq 0 ] && [ -n "${MAPPINGS:-}" ] \
      && [ "$f" = "$MAPPINGS" ] && continue
    inputs+=( --input "$f" )
  done < <(ontology_files_under "$MODULES_DIR")
  while read -r f; do
    [ -n "${f:-}" ] || continue
    [ "$include_mapping" -eq 0 ] && [ -n "${MAPPINGS:-}" ] \
      && [ "$f" = "$MAPPINGS" ] && continue
    inputs+=( --input "$f" )
  done < <(ontology_files_under "$ANNOT_DIR")

  # Print as lines so Bash 3.2 callers can populate an array.
  if [ "${#inputs[@]}" -gt 0 ]; then
    printf '%s\n' "${inputs[@]}"
  fi
}

# Export TOOLBOX_MODE for scripts that need to know
export TOOLBOX_MODE
