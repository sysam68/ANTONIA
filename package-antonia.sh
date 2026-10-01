#!/usr/bin/env bash
# Build the versioned ANTONIA toolbox asset consumed by the installers.

set -euo pipefail

usage() {
  echo "Usage: ./package-antonia.sh <release-tag>" >&2
}

VERSION="${1:-}"
case "$VERSION" in
  *[!A-Za-z0-9._-]*|'') usage; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIST="$ROOT/dist"
ASSET_NAME="antonia-toolbox.tar.gz"
TEMP_ROOT="$(mktemp -d "$ROOT/.antonia-package.XXXXXX")"

cleanup() {
  case "$TEMP_ROOT" in
    "$ROOT"/.antonia-package.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$TEMP_ROOT/toolbox" "$DIST"

if [ ! -f "$ROOT/toolbox/Makefile" ]; then
  echo "Error: missing ontology host Makefile: toolbox/Makefile" >&2
  exit 1
fi
cp "$ROOT/toolbox/Makefile" "$TEMP_ROOT/toolbox/Makefile"

if [ ! -f "$ROOT/toolbox/AGENTS.md" ]; then
  echo "Error: missing ontology host guidance: toolbox/AGENTS.md" >&2
  exit 1
fi
cp "$ROOT/toolbox/AGENTS.md" "$TEMP_ROOT/toolbox/AGENTS.md"

TOOLBOX_FILES=(
  common.sh
  diff.sh
  generate_from_templates.sh
  import.sh
  init_project.sh
  install_robot.sh
  java_conf.sh
  progress.sh
  project_ql.sh
  reason.sh
  release.sh
  report.sh
  update_config.sh
  validate.sh
  validate_dl.sh
  validate_ql.sh
)

for file in "${TOOLBOX_FILES[@]}"; do
  if [ ! -f "$ROOT/toolbox/$file" ]; then
    echo "Error: missing toolbox file: toolbox/$file" >&2
    exit 1
  fi
  cp "$ROOT/toolbox/$file" "$TEMP_ROOT/toolbox/$file"
done

if [ ! -d "$ROOT/toolbox/docs" ]; then
  echo "Error: missing toolbox documentation: toolbox/docs" >&2
  exit 1
fi
cp -R "$ROOT/toolbox/docs" "$TEMP_ROOT/toolbox/docs"

if [ ! -d "$ROOT/toolbox/templates" ]; then
  echo "Error: missing toolbox templates: toolbox/templates" >&2
  exit 1
fi
cp -R "$ROOT/toolbox/templates" "$TEMP_ROOT/toolbox/templates"

printf 'format=1\nversion=%s\nrepository=%s\n' \
  "$VERSION" "sysam68/ANTONIA" > "$TEMP_ROOT/toolbox/.antonia-managed"
chmod +x "$TEMP_ROOT/toolbox"/*.sh

ARCHIVE="$DIST/$ASSET_NAME"
CHECKSUM="$ARCHIVE.sha256"
rm -f -- "$ARCHIVE" "$CHECKSUM"

COPYFILE_DISABLE=1 tar -czf "$ARCHIVE" -C "$TEMP_ROOT" toolbox

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$ARCHIVE" | awk '{ print $1 }' > "$CHECKSUM"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$ARCHIVE" | awk '{ print $1 }' > "$CHECKSUM"
else
  echo "Error: sha256sum or shasum is required." >&2
  exit 1
fi

echo "Created: $ARCHIVE"
echo "Created: $CHECKSUM"
