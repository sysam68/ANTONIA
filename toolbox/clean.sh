#!/usr/bin/env bash
# Remove the configured ontology build directory without requiring ROBOT/Java.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ENV_FILE="$ROOT/config/config.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "✖ config.env not found at: $ENV_FILE" >&2
  exit 1
fi

set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

if ! declare -p TARGET >/dev/null 2>&1 || [ -z "$TARGET" ]; then
  echo "✖ TARGET must be configured in ${ENV_FILE#$ROOT/}." >&2
  exit 1
fi

case "/$TARGET/" in
  */../*|*/./*)
    echo "✖ Refusing unsafe TARGET path: $TARGET" >&2
    exit 1
    ;;
esac

case "$TARGET" in
  /*) target_path="$TARGET" ;;
  *) target_path="$ROOT/$TARGET" ;;
esac

case "$target_path" in
  "$ROOT"|"$ROOT/")
    echo "✖ Refusing to clean the ontology repository root." >&2
    exit 1
    ;;
  "$ROOT"/*) ;;
  *)
    echo "✖ TARGET must resolve inside the ontology repository: $TARGET" >&2
    exit 1
    ;;
esac

rm -rf -- "$target_path"
echo "✓ cleaned ${target_path#$ROOT/}/"
