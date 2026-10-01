#!/usr/bin/env bash
# Verify bootstrap cleanup and in-toolbox lifecycle scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SUCCESS_ROOT="$(mktemp -d /tmp/antonia-lifecycle-success.XXXXXX)"
FAILURE_ROOT="$(mktemp -d /tmp/antonia-lifecycle-failure.XXXXXX)"

cleanup() {
  case "$SUCCESS_ROOT" in
    /tmp/antonia-lifecycle-success.*) rm -rf -- "$SUCCESS_ROOT" ;;
  esac
  case "$FAILURE_ROOT" in
    /tmp/antonia-lifecycle-failure.*) rm -rf -- "$FAILURE_ROOT" ;;
  esac
}
trap cleanup EXIT

git -C "$SUCCESS_ROOT" init -q
cp "$ROOT/install-antonia.sh" "$SUCCESS_ROOT/install-antonia.sh"
ANTONIA_RELEASE_BASE_URL="file://$ROOT/dist" \
  "$SUCCESS_ROOT/install-antonia.sh" > "$SUCCESS_ROOT/install.log"

test ! -e "$SUCCESS_ROOT/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
grep -q 'Removed bootstrap installer: install-antonia.sh' "$SUCCESS_ROOT/install.log"

touch "$SUCCESS_ROOT/toolbox/stale-before-update"
ANTONIA_RELEASE_BASE_URL="file://$ROOT/dist" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" > "$SUCCESS_ROOT/update.log"

test ! -e "$SUCCESS_ROOT/toolbox/stale-before-update"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
grep -q 'ANTONIA toolbox updated:' "$SUCCESS_ROOT/update.log"

git -C "$FAILURE_ROOT" init -q
cp "$ROOT/install-antonia.sh" "$FAILURE_ROOT/install-antonia.sh"
if ANTONIA_RELEASE_BASE_URL="file://$FAILURE_ROOT/missing-release" \
    "$FAILURE_ROOT/install-antonia.sh" > "$FAILURE_ROOT/install.log" 2>&1; then
  echo "Error: installation unexpectedly succeeded" >&2
  exit 1
fi
test -f "$FAILURE_ROOT/install-antonia.sh"

echo "lifecycle scripts test: passed"
