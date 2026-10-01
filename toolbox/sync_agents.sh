#!/usr/bin/env bash
# Synchronize ANTONIA-managed repository skills without replacing unrelated ones.

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/.." && pwd -P)"
SOURCE_ROOT="$TOOLBOX_DIR/.agents"
SOURCE_MANIFEST="$SOURCE_ROOT/.antonia-managed"
DESTINATION_ROOT="$HOST_ROOT/.agents"
DESTINATION_MANIFEST="$DESTINATION_ROOT/.antonia-managed"

validate_skill_path() {
  local relative_path="$1"

  case "$relative_path" in
    skills/*)
      case "${relative_path#skills/}" in
        ''|*/*|.*|*..*|*[!A-Za-z0-9._-]*)
          echo "Error: invalid managed skill path: $relative_path" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Error: unsupported managed agent path: $relative_path" >&2
      exit 1
      ;;
  esac
}

is_previously_managed() {
  local expected_path="$1"
  local line=""

  [ -f "$DESTINATION_MANIFEST" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    [ "$line" = "skill=$expected_path" ] && return 0
  done < "$DESTINATION_MANIFEST"

  return 1
}

if [ ! -f "$SOURCE_MANIFEST" ]; then
  echo "Error: missing ANTONIA agent manifest: $SOURCE_MANIFEST" >&2
  exit 1
fi
if ! grep -Fqx 'format=1' "$SOURCE_MANIFEST"; then
  echo "Error: invalid ANTONIA agent manifest format." >&2
  exit 1
fi
if ! grep -q '^skill=skills/' "$SOURCE_MANIFEST"; then
  echo "Error: the ANTONIA agent manifest declares no skills." >&2
  exit 1
fi

if [ -f "$DESTINATION_MANIFEST" ]; then
  if ! grep -Fqx 'format=1' "$DESTINATION_MANIFEST"; then
    echo "Error: invalid installed ANTONIA agent manifest format." >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      format=1|'') ;;
      skill=*) validate_skill_path "${line#skill=}" ;;
      *)
        echo "Error: invalid installed ANTONIA agent manifest entry: $line" >&2
        exit 1
        ;;
    esac
  done < "$DESTINATION_MANIFEST"
fi

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    format=1|'') ;;
    skill=*)
      relative_path="${line#skill=}"
      validate_skill_path "$relative_path"
      if [ ! -f "$SOURCE_ROOT/$relative_path/SKILL.md" ]; then
        echo "Error: incomplete managed skill: $relative_path" >&2
        exit 1
      fi
      if [ -e "$DESTINATION_ROOT/$relative_path" ] \
          && ! is_previously_managed "$relative_path"; then
        echo "Error: refusing to replace unmanaged skill: .agents/$relative_path" >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: invalid ANTONIA agent manifest entry: $line" >&2
      exit 1
      ;;
  esac
done < "$SOURCE_MANIFEST"

if [ -f "$DESTINATION_MANIFEST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      skill=*)
        relative_path="${line#skill=}"
        validate_skill_path "$relative_path"
        managed_path="$DESTINATION_ROOT/$relative_path"
        case "$managed_path" in
          "$DESTINATION_ROOT"/skills/*) rm -rf -- "$managed_path" ;;
        esac
        ;;
    esac
  done < "$DESTINATION_MANIFEST"
fi

mkdir -p "$DESTINATION_ROOT/skills"

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    skill=*)
      relative_path="${line#skill=}"
      cp -R "$SOURCE_ROOT/$relative_path" "$DESTINATION_ROOT/$relative_path"
      echo "Ontology skill updated: .agents/$relative_path"
      ;;
  esac
done < "$SOURCE_MANIFEST"

cp "$SOURCE_MANIFEST" "$DESTINATION_MANIFEST"
