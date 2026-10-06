#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reason.sh
# Build the working ontology and run reasoning with ROBOT.
#
# Steps:
#   1) Generate RDF/XML modules from all TSV templates (classes, annotations, ABox)
#   2) Run the source controls configured by qc/profile.txt
#   3) Merge TBox + (optional) ABox + mappings + imports + generated modules
#   4) Classify with the selected reasoner (default: ELK)
#
# Outputs use OUTPUT_FORMAT (rdf, ttl, or owl):
#   - TARGET/merged.<format>
#   - TARGET/classified.<format>
#
# Environment variables:
#   REASONER=hermit|jfact|ELK|structural   (default: ELK)
#   SKIP_TEMPLATES=1                       (skip TSV->RDF/XML generation)
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

REASON_RUNTIME_DIR=""

cleanup_reason_runtime() {
  [ -n "$REASON_RUNTIME_DIR" ] || return 0
  case "$REASON_RUNTIME_DIR" in
    */antonia-reason.*) rm -rf -- "$REASON_RUNTIME_DIR" ;;
  esac
}
trap cleanup_reason_runtime EXIT

# 1) TSV -> RDF/XML generation (optional)
if [ "${SKIP_TEMPLATES:-0}" != "1" ]; then
  "$(dirname "$0")/generate_from_templates.sh"
else
  echo "▶ Skipping TSV → RDF/XML generation (SKIP_TEMPLATES=1)"
fi

# 2) Build merge input list from known locations
echo "▶ Building merge input list"
MERGE_INPUTS=()
while IFS= read -r arg; do
  MERGE_INPUTS+=("$arg")
done < <(build_merge_inputs)

# A newly initialized project may not contain ontology sources yet. This is a
# valid no-op; once at least one source exists, the normal merge/reasoning path
# remains mandatory.
if [ "${#MERGE_INPUTS[@]}" -eq 0 ]; then
  echo "ℹ no import or files to merge; skipping reasoning."
  exit 0
fi

# qc/profile.txt is the sole control configuration. Its optional third column
# assigns source controls to project-source or non-mapping-source scope.
EQUIVALENCE_POLICY="none"
NON_MAPPING_INPUTS=()
while IFS= read -r arg; do
  NON_MAPPING_INPUTS+=("$arg")
done < <(build_merge_inputs 0)

PROJECT_SOURCES=()
while IFS= read -r source_ontology; do
  [ -n "${source_ontology:-}" ] || continue
  PROJECT_SOURCES+=("$source_ontology")
done < <(project_source_files)

append_source_controls() {
  local expected_scope="$1"
  local destination="$2"
  local profile_line=""
  local profile_rest=""
  local profile_scope=""
  local control_name=""
  local severity=""
  local query=""
  local rendered_query=""

  while IFS= read -r profile_line || [ -n "$profile_line" ]; do
    case "$profile_line" in
      *$'\t'*)
        severity="${profile_line%%$'\t'*}"
        profile_rest="${profile_line#*$'\t'}"
        control_name="${profile_rest%%$'\t'*}"
        if [ "$profile_rest" = "$control_name" ]; then
          profile_scope=""
        else
          profile_scope="${profile_rest#*$'\t'}"
          profile_scope="${profile_scope%%$'\t'*}"
        fi
        ;;
      *) continue ;;
    esac
    validate_control_scope "$profile_scope"
    [ "$profile_scope" = "$expected_scope" ] || continue
    validate_control_name "$control_name"
    query="$(control_query_path "$control_name")"
    if [ -f "$query" ]; then
      rendered_query="$REASON_RUNTIME_DIR/$control_name.rq"
      render_robot_query "$query" "$rendered_query"
      printf '%s\tfile://%s\n' "$severity" "$rendered_query" >> "$destination"
    elif [ "${control_name#example-}" != "$control_name" ]; then
      echo "✖ Enabled SPARQL control is missing: ${query#$ROOT/}" >&2
      return 1
    else
      printf '%s\t%s\n' "$severity" "$control_name" >> "$destination"
    fi
  done < "$PROFILE"
}

if [ "${#NON_MAPPING_INPUTS[@]}" -gt 0 ]; then
  if [ ! -f "$PROFILE" ]; then
    echo "✖ QC profile not found at: ${PROFILE#$ROOT/}" >&2
    exit 1
  fi

  REASON_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/antonia-reason.XXXXXX")"
  NON_MAPPING_PROFILE="$REASON_RUNTIME_DIR/non-mapping-source-profile.txt"
  : > "$NON_MAPPING_PROFILE"
  append_source_controls "non-mapping-source" "$NON_MAPPING_PROFILE"
  PROJECT_SOURCE_PROFILE="$REASON_RUNTIME_DIR/project-source-profile.txt"
  cp "$NON_MAPPING_PROFILE" "$PROJECT_SOURCE_PROFILE"
  append_source_controls "project-source" "$PROJECT_SOURCE_PROFILE"
  mapping_display="${MAPPINGS#$ROOT/}"
  [ -n "$mapping_display" ] || mapping_display="the configured MAPPINGS ontology"
  echo "▶ Validating ontology sources before merge"
  source_index=1
  input_index=1
  while [ "$input_index" -lt "${#NON_MAPPING_INPUTS[@]}" ]; do
    source_ontology="${NON_MAPPING_INPUTS[$input_index]}"
    source_output="$REASON_RUNTIME_DIR/source-$source_index.tsv"
    source_log="$REASON_RUNTIME_DIR/source-$source_index.log"
    source_profile="$NON_MAPPING_PROFILE"
    source_scope="external import"
    for project_source in "${PROJECT_SOURCES[@]}"; do
      if [ "$source_ontology" = "$project_source" ]; then
        source_profile="$PROJECT_SOURCE_PROFILE"
        source_scope="project-owned ontology"
        break
      fi
    done
    if [ ! -s "$source_profile" ]; then
      source_index=$((source_index + 1))
      input_index=$((input_index + 2))
      continue
    fi
    echo "  - ${source_ontology#$ROOT/} ($source_scope)"
    report_cmd=( robot report \
      --input "$source_ontology" \
      --profile "$source_profile" \
      --fail-on "$FAIL_ON" \
      --output "$source_output" )
    [ -f "$CATALOG" ] && report_cmd+=( --catalog "$CATALOG" )
    if ! "${report_cmd[@]}" > "$source_log" 2>&1; then
      cat "$source_log" >&2
      [ ! -s "$source_output" ] || cat "$source_output" >&2
      echo "✖ Ontology source control failed before merge." >&2
      echo "  Source: ${source_ontology#$ROOT/}" >&2
      if [ "$source_scope" = "project-owned ontology" ] \
          && { grep -Eq 'example-forbidden_iri|ENTITY_OUTSIDE_BASE_IRI|VERSIONED_ENTITY_IRI|INSTANCE_OUTSIDE_INSTANCE_BASE_IRI' \
            "$source_log" "$source_output" 2>/dev/null; }; then
        echo "  IRI ownership applies only to project-owned sources, not imports or MAPPINGS." >&2
      fi
      if grep -Eqi 'example-forbidden_equivalence|equivalentClass|class equivalence' \
          "$source_log" "$source_output" 2>/dev/null; then
        echo "  Class equivalence is forbidden outside $mapping_display." >&2
      fi
      exit 1
    fi
    source_index=$((source_index + 1))
    input_index=$((input_index + 2))
  done
fi

if [ -n "${MAPPINGS:-}" ] && [ -f "$MAPPINGS" ]; then
  EQUIVALENCE_POLICY="asserted-only"
fi

# 2a) Merge
MERGED_ROBOT_OUTPUT="$(robot_output_path "$MERGED_ONTOLOGY")"
echo "▶ Merging ontologies → ${MERGED_ONTOLOGY#$ROOT/}"
robot merge "${MERGE_INPUTS[@]}" --output "$MERGED_ROBOT_OUTPUT"
finalize_robot_output "$MERGED_ONTOLOGY" "$MERGED_ROBOT_OUTPUT"

# 3) Reason
CLASSIFIED_ROBOT_OUTPUT="$(robot_output_path "$CLASSIFIED_ONTOLOGY")"
echo "▶ Reasoning with ${REASONER} → ${CLASSIFIED_ONTOLOGY#$ROOT/}"
echo "  - Equivalent classes allowed: ${EQUIVALENCE_POLICY}"
robot reason \
  --input "$MERGED_ONTOLOGY" \
  --reasoner "$REASONER" \
  --equivalent-classes-allowed "$EQUIVALENCE_POLICY" \
  --exclude-tautologies structural \
  --output "$CLASSIFIED_ROBOT_OUTPUT"
finalize_robot_output "$CLASSIFIED_ONTOLOGY" "$CLASSIFIED_ROBOT_OUTPUT"

echo "✓ Reasoning complete"
echo "  - Merged:     ${MERGED_ONTOLOGY#$ROOT/}"
echo "  - Classified: ${CLASSIFIED_ONTOLOGY#$ROOT/}"
