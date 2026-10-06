#!/usr/bin/env bash
# Migrate known ANTONIA example-control entries while preserving the project's
# selected controls and every unrelated qc/profile.txt line.

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/.." && pwd -P)"
CONFIG_FILE="$HOST_ROOT/config/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: project configuration is missing: $CONFIG_FILE" >&2
  exit 1
fi

PROFILE_PATH="$(
  set +u
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  printf '%s\n' "${PROFILE:-qc/profile.txt}"
)"

case "$PROFILE_PATH" in
  /*) PROFILE_FILE="$PROFILE_PATH" ;;
  *) PROFILE_FILE="$HOST_ROOT/$PROFILE_PATH" ;;
esac

case "$PROFILE_FILE" in
  "$HOST_ROOT"/*) ;;
  *)
    echo "Error: PROFILE must stay inside the ontology repository: $PROFILE_PATH" >&2
    exit 1
    ;;
esac
case "/${PROFILE_FILE#$HOST_ROOT/}/" in
  */../*|*/./*)
    echo "Error: unsafe PROFILE path: $PROFILE_PATH" >&2
    exit 1
    ;;
esac

if [ ! -f "$PROFILE_FILE" ]; then
  echo "Error: QC profile is missing: $PROFILE_PATH" >&2
  exit 1
fi

PROFILE_DIR="$(cd "$(dirname "$PROFILE_FILE")" && pwd -P)"
case "$PROFILE_DIR" in
  "$HOST_ROOT"/*) ;;
  *)
    echo "Error: resolved PROFILE leaves the ontology repository: $PROFILE_PATH" >&2
    exit 1
    ;;
esac

TEMP_PROFILE="$(mktemp "$HOST_ROOT/.antonia-profile.XXXXXX")"
cleanup() {
  case "$TEMP_PROFILE" in
    "$HOST_ROOT"/.antonia-profile.*) rm -f -- "$TEMP_PROFILE" ;;
  esac
}
trap cleanup EXIT

awk -F '\t' -v OFS='\t' '
  $2 == "forbidden_iri" {
    print $1, "example-forbidden_iri", "project-source"
    next
  }
  $2 == "forbidden_equivalence" {
    print $1, "example-forbidden_equivalence", "non-mapping-source"
    next
  }
  { print }
' "$PROFILE_FILE" > "$TEMP_PROFILE"

if cmp -s "$PROFILE_FILE" "$TEMP_PROFILE"; then
  echo "QC profile already follows the ANTONIA control convention: ${PROFILE_FILE#$HOST_ROOT/}"
else
  cp "$TEMP_PROFILE" "$PROFILE_FILE"
  echo "QC profile migrated to ANTONIA example-control names: ${PROFILE_FILE#$HOST_ROOT/}"
fi
