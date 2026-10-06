#!/usr/bin/env bash
# Copy ANTONIA-distributed ROBOT controls into the configured project checks
# directory while preserving unrelated project controls.

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_ROOT="$(cd "$TOOLBOX_DIR/.." && pwd -P)"
CONFIG_FILE="$HOST_ROOT/config/config.env"
SOURCE_DIR="$TOOLBOX_DIR/checks"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: ANTONIA controls are missing: $SOURCE_DIR" >&2
  exit 1
fi
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: project configuration is missing: $CONFIG_FILE" >&2
  exit 1
fi

SPARQL_CHECKS="$(
  set +u
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  printf '%s\n' "${SPARQL_CHECKS:-src/sparql/checks}"
)"

case "$SPARQL_CHECKS" in
  /*) DESTINATION="$SPARQL_CHECKS" ;;
  *) DESTINATION="$HOST_ROOT/$SPARQL_CHECKS" ;;
esac

case "$DESTINATION" in
  "$HOST_ROOT"/*) ;;
  *)
    echo "Error: SPARQL_CHECKS must stay inside the ontology repository: $SPARQL_CHECKS" >&2
    exit 1
    ;;
esac
case "/${DESTINATION#$HOST_ROOT/}/" in
  */../*|*/./*)
    echo "Error: unsafe SPARQL_CHECKS path: $SPARQL_CHECKS" >&2
    exit 1
    ;;
esac

mkdir -p "$DESTINATION"
DESTINATION="$(cd "$DESTINATION" && pwd -P)"
case "$DESTINATION" in
  "$HOST_ROOT"/*) ;;
  *)
    echo "Error: resolved SPARQL_CHECKS leaves the ontology repository: $SPARQL_CHECKS" >&2
    exit 1
    ;;
esac
copied=0
for source in "$SOURCE_DIR"/*.rq; do
  [ -f "$source" ] || continue
  cp "$source" "$DESTINATION/$(basename "$source")"
  copied=$((copied + 1))
done

if [ "$copied" -eq 0 ]; then
  echo "Error: ANTONIA declares no ROBOT controls under $SOURCE_DIR" >&2
  exit 1
fi

echo "ANTONIA controls synchronized: ${DESTINATION#$HOST_ROOT/} ($copied files)"
