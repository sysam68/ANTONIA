#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# import.sh
# Fetch GitHub Release ontology assets into the configured IMPORTS_DIR.
#
# config/import.env is a strict TSV file with three columns:
#   1) GitHub repository URL followed by #release-asset
#   2) immutable GitHub Release tag, or "latest"
#   3) local basename without extension
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONF_FILE="$ROOT/config/import.env"
ENV_FILE="$ROOT/config/config.env"

[ -f "$CONF_FILE" ] || { echo "✖ Config not found: ${CONF_FILE#$ROOT/}" >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "✖ Config not found: ${ENV_FILE#$ROOT/}" >&2; exit 1; }

# Load IMPORTS_DIR without pulling in common.sh, because downloading imports
# must not require Java or ROBOT.
set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport
: "${IMPORTS_DIR:=src/edit/imports}"

case "$IMPORTS_DIR" in
  /*) DEST_DIR="$IMPORTS_DIR" ;;
  *)  DEST_DIR="$ROOT/$IMPORTS_DIR" ;;
esac

make_temp_dir() {
  local d
  if d="$(mktemp -d -t antonia-import.XXXXXX 2>/dev/null)"; then
    printf '%s\n' "$d"
    return
  fi
  mktemp -d "${TMPDIR:-/tmp}/antonia-import.XXXXXX"
}

trim() {
  awk '{$1=$1; print}'
}

validate_download() {
  local file="$1"
  [ -s "$file" ] || { echo "✖ Downloaded import is empty: $file" >&2; return 1; }

  # A GitHub /blob/ page can return HTTP 200 while containing HTML rather than
  # RDF. Reject common HTML signatures before installing the file.
  if LC_ALL=C head -c 1024 "$file" | grep -Eiq '<!doctype[[:space:]]+html|<html([[:space:]>])'; then
    echo "✖ Downloaded import is HTML, not an ontology: $file" >&2
    return 1
  fi
}

github_repo_slug() {
  local repo_url="$1"
  local slug

  case "$repo_url" in
    https://github.com/*) slug="${repo_url#https://github.com/}" ;;
    git@github.com:*) slug="${repo_url#git@github.com:}" ;;
    ssh://git@github.com/*) slug="${repo_url#ssh://git@github.com/}" ;;
    *) return 1 ;;
  esac

  slug="${slug%/}"
  slug="${slug%.git}"
  case "$slug" in
    */*/*|/*|*/) return 1 ;;
    */*) ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$slug"
}

install_import() {
  local source_file="$1"
  local destination="$2"
  local local_name="$3"
  local staged="${destination}.tmp.$$"

  validate_download "$source_file"
  cp -f "$source_file" "$staged"
  mv -f "$staged" "$destination"

  # Avoid merging a stale previous serialization of the same imported graph.
  local candidate
  for candidate in \
    "$DEST_DIR/${local_name}.rdf" \
    "$DEST_DIR/${local_name}.owl" \
    "$DEST_DIR/${local_name}.ttl"; do
    [ "$candidate" = "$destination" ] || rm -f "$candidate"
  done
}

mkdir -p "$DEST_DIR"
TEMP_ROOT="$(make_temp_dir)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo "▶ Reading import manifest: ${CONF_FILE#$ROOT/}"
lineno=0
imported=0

while IFS=$'\t' read -r URL REF LOCAL_NAME EXTRA || [ -n "${URL:-}" ]; do
  lineno=$((lineno + 1))
  URL="$(printf '%s' "${URL:-}" | trim)"

  [ -z "$URL" ] && continue
  case "$URL" in \#*|";"*) continue ;; esac

  REF="$(printf '%s' "${REF:-}" | trim)"
  LOCAL_NAME="$(printf '%s' "${LOCAL_NAME:-}" | trim)"
  EXTRA="$(printf '%s' "${EXTRA:-}" | trim)"

  if [ -z "$LOCAL_NAME" ] || [ -n "$EXTRA" ]; then
    echo "✖ Line $lineno must contain exactly three tab-separated columns" >&2
    exit 1
  fi
  case "$LOCAL_NAME" in
    *[!A-Za-z0-9._-]*) echo "✖ Line $lineno has an unsafe local name: $LOCAL_NAME" >&2; exit 1 ;;
  esac

  if [[ "$URL" != *"#"* ]]; then
    echo "✖ Line $lineno must use GitHub repository#release-asset syntax" >&2
    exit 1
  fi

  command -v gh >/dev/null 2>&1 || {
    echo "✖ 'gh' not found in PATH (required for GitHub Release imports)" >&2
    exit 1
  }

  REPO_URL="${URL%%#*}"
  ASSET_NAME="${URL#*#}"
  [ -n "$REF" ] && [ "$REF" != "-" ] || {
    echo "✖ Line $lineno requires a GitHub Release tag or 'latest'" >&2
    exit 1
  }
  case "$ASSET_NAME" in
    ""|*[!A-Za-z0-9._+-]*)
      echo "✖ Line $lineno has an unsafe GitHub Release asset name: $ASSET_NAME" >&2
      exit 1
      ;;
  esac

  REPO_SLUG="$(github_repo_slug "$REPO_URL")" || {
    echo "✖ Line $lineno is not a supported GitHub repository URL: $REPO_URL" >&2
    exit 1
  }
  if [ "$REF" = "latest" ]; then
    RESOLVED_RELEASE="$(gh release view \
      --repo "$REPO_SLUG" \
      --json tagName \
      --jq '.tagName')"
  else
    RESOLVED_RELEASE="$(gh release view "$REF" \
      --repo "$REPO_SLUG" \
      --json tagName \
      --jq '.tagName')"
  fi
  [ -n "$RESOLVED_RELEASE" ] || {
    echo "✖ Line $lineno could not resolve GitHub Release '$REF'" >&2
    exit 1
  }

  SRC_EXT="${ASSET_NAME##*.}"
  WORKDIR="$TEMP_ROOT/line-$lineno"
  mkdir -p "$WORKDIR"

  echo "→ [$lineno] GitHub Release $REPO_SLUG@$RESOLVED_RELEASE:$ASSET_NAME"
  gh release download "$RESOLVED_RELEASE" \
    --repo "$REPO_SLUG" \
    --pattern "$ASSET_NAME" \
    --dir "$WORKDIR"

  SOURCE_FILE="$WORKDIR/$ASSET_NAME"
  [ -f "$SOURCE_FILE" ] || {
    echo "✖ Line $lineno: asset not found in GitHub Release: $ASSET_NAME" >&2
    exit 1
  }

  case "$SRC_EXT" in
    rdf|owl|ttl) ;;
    *) echo "✖ Line $lineno has an unsupported ontology extension: $SRC_EXT" >&2; exit 1 ;;
  esac

  DEST_FILE="$DEST_DIR/${LOCAL_NAME}.${SRC_EXT}"
  install_import "$SOURCE_FILE" "$DEST_FILE" "$LOCAL_NAME"
  echo "  ✓ ${DEST_FILE#$ROOT/}"
  imported=$((imported + 1))
done < "$CONF_FILE"

[ "$imported" -gt 0 ] || { echo "✖ No imports declared in ${CONF_FILE#$ROOT/}" >&2; exit 1; }
echo "✓ Imported $imported ontology artifact(s) into ${DEST_DIR#$ROOT/}"
