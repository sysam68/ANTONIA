#!/usr/bin/env bash
# Add variables introduced by the installed ANTONIA release without modifying
# or deleting any existing project configuration assignment.

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/.." && pwd -P)"
TEMPLATE_DIR="$TOOLBOX_DIR/templates/config"
MANAGED_MARKER="$TOOLBOX_DIR/.antonia-managed"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: ANTONIA configuration templates are missing: $TEMPLATE_DIR" >&2
  exit 1
fi

VERSION="unknown"
if [ -f "$MANAGED_MARKER" ]; then
  VERSION="$(awk -F= '$1 == "version" { print $2; exit }' "$MANAGED_MARKER")"
  VERSION="${VERSION:-unknown}"
fi

TEMP_ROOT="$(mktemp -d "$HOST_ROOT/.antonia-config.XXXXXX")"
cleanup() {
  case "$TEMP_ROOT" in
    "$HOST_ROOT"/.antonia-config.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

extract_variables() {
  awk '
    function variable_name(line, value, name) {
      value = line
      sub(/^[[:space:]]*/, "", value)
      sub(/^export[[:space:]]+/, "", value)
      if (value !~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) return ""
      name = value
      sub(/[[:space:]]*=.*/, "", name)
      return name
    }
    {
      name = variable_name($0)
      if (name != "" && !seen[name]++) print name "\t" $0
    }
  ' "$1"
}

print_names() {
  if [ ! -s "$1" ]; then
    printf 'none'
    return
  fi
  awk -F '\t' '
    BEGIN { separator = "" }
    { printf "%s%s", separator, $1; separator = ", " }
  ' "$1"
}

ensure_gitignore_entry() {
  local path="$1"
  local entry="$2"

  if [ -f "$path" ] && grep -Fqx "$entry" "$path"; then
    return 0
  fi
  if [ -s "$path" ] && [ -n "$(tail -c 1 "$path")" ]; then
    printf '\n' >> "$path"
  fi
  printf '%s\n' "$entry" >> "$path"
}

shopt -s nullglob
TEMPLATES=("$TEMPLATE_DIR"/*.env)
shopt -u nullglob

if [ "${#TEMPLATES[@]}" -eq 0 ]; then
  echo "Error: no configuration template found in $TEMPLATE_DIR" >&2
  exit 1
fi

echo "Checking project configuration against ANTONIA $VERSION"

for template in "${TEMPLATES[@]}"; do
  filename="$(basename "$template")"
  target="$HOST_ROOT/config/$filename"
  expected="$TEMP_ROOT/$filename.expected"
  current="$TEMP_ROOT/$filename.current"
  existing="$TEMP_ROOT/$filename.existing"
  added="$TEMP_ROOT/$filename.added"
  removed="$TEMP_ROOT/$filename.removed"

  extract_variables "$template" > "$expected"
  if [ -f "$target" ]; then
    extract_variables "$target" > "$current"
  else
    : > "$current"
  fi

  awk -F '\t' 'FILENAME == ARGV[1] { current[$1] = 1; next } $1 in current' \
    "$current" "$expected" > "$existing"
  awk -F '\t' 'FILENAME == ARGV[1] { current[$1] = 1; next } !($1 in current)' \
    "$current" "$expected" > "$added"
  awk -F '\t' 'FILENAME == ARGV[1] { expected[$1] = 1; next } !($1 in expected)' \
    "$expected" "$current" > "$removed"

  echo "  $filename"
  printf '    Existing variables: '; print_names "$existing"; printf '\n'
  printf '    New variables:      '; print_names "$added"; printf '\n'
  printf '    No longer expected: '; print_names "$removed"; printf '\n'

  if [ -s "$added" ]; then
    mkdir -p "$(dirname "$target")"
    if [ -f "$target" ]; then
      printf '\n# Added by ANTONIA %s\n' "$VERSION" >> "$target"
    fi
    awk '
      {
        separator = index($0, "\t")
        if (separator > 0) print substr($0, separator + 1)
      }
    ' "$added" >> "$target"
    echo "    Result: new variables appended; existing content preserved."
  else
    echo "    Result: no change."
  fi
done

# Keep the source layout introduced by newer ANTONIA releases additive during
# upgrades. These directories are project-owned: never move, replace, or
# remove their existing contents.
mkdir -p \
  "$HOST_ROOT/src/edit/mappings" \
  "$HOST_ROOT/src/edit/services"
ensure_gitignore_entry "$HOST_ROOT/.gitignore" "src/edit/**/*.properties"

# Older ANTONIA updaters invoke only the candidate release's update_config.sh
# after swapping toolboxes. Keep the profile migration and control copy behind
# that stable lifecycle hook so upgrades from those releases remain complete.
bash "$TOOLBOX_DIR/update_profile.sh"
bash "$TOOLBOX_DIR/sync_checks.sh"
