#!/usr/bin/env bash
# Verify bootstrap cleanup and in-toolbox lifecycle scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
RELEASE_ROOT="$(mktemp -d /tmp/antonia-lifecycle-release.XXXXXX)"
SUCCESS_ROOT="$(mktemp -d /tmp/antonia-lifecycle-success.XXXXXX)"
FAILURE_ROOT="$(mktemp -d /tmp/antonia-lifecycle-failure.XXXXXX)"

cleanup() {
  case "$RELEASE_ROOT" in
    /tmp/antonia-lifecycle-release.*) rm -rf -- "$RELEASE_ROOT" ;;
  esac
  case "$SUCCESS_ROOT" in
    /tmp/antonia-lifecycle-success.*) rm -rf -- "$SUCCESS_ROOT" ;;
  esac
  case "$FAILURE_ROOT" in
    /tmp/antonia-lifecycle-failure.*) rm -rf -- "$FAILURE_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$RELEASE_ROOT/stage"
tar -xzf "$ROOT/dist/antonia-toolbox.tar.gz" -C "$RELEASE_ROOT/stage"
cp "$ROOT/tests/data/install-robot-stub.sh" \
  "$RELEASE_ROOT/stage/toolbox/install_robot.sh"
chmod +x "$RELEASE_ROOT/stage/toolbox/install_robot.sh"
COPYFILE_DISABLE=1 tar -czf "$RELEASE_ROOT/antonia-toolbox.tar.gz" \
  -C "$RELEASE_ROOT/stage" toolbox
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$RELEASE_ROOT/antonia-toolbox.tar.gz" | awk '{ print $1 }' \
    > "$RELEASE_ROOT/antonia-toolbox.tar.gz.sha256"
else
  shasum -a 256 "$RELEASE_ROOT/antonia-toolbox.tar.gz" | awk '{ print $1 }' \
    > "$RELEASE_ROOT/antonia-toolbox.tar.gz.sha256"
fi

git -C "$SUCCESS_ROOT" init -q
printf 'project-specific-rule\n' > "$SUCCESS_ROOT/.gitignore"
cp "$ROOT/install-antonia.sh" "$SUCCESS_ROOT/install-antonia.sh"
ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/install-antonia.sh" > "$SUCCESS_ROOT/install.log"

test ! -e "$SUCCESS_ROOT/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
test -f "$SUCCESS_ROOT/.tools/install-robot-invoked"
grep -Fqx 'project-specific-rule' "$SUCCESS_ROOT/.gitignore"
test "$(grep -Fxc 'tmp/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc '.tools/' "$SUCCESS_ROOT/.gitignore")" -eq 1
grep -q 'Installing the repository-local ROBOT toolchain' "$SUCCESS_ROOT/install.log"
grep -q 'Removed bootstrap installer: install-antonia.sh' "$SUCCESS_ROOT/install.log"

bash "$SUCCESS_ROOT/toolbox/init_project.sh" > "$SUCCESS_ROOT/reinit.log"
test "$(grep -Fxc 'tmp/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc '.tools/' "$SUCCESS_ROOT/.gitignore")" -eq 1

touch "$SUCCESS_ROOT/toolbox/stale-before-update"
ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" > "$SUCCESS_ROOT/update.log"

test ! -e "$SUCCESS_ROOT/toolbox/stale-before-update"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
grep -q 'ANTONIA toolbox updated:' "$SUCCESS_ROOT/update.log"

git -C "$FAILURE_ROOT" init -q
cp "$ROOT/install-antonia.sh" "$FAILURE_ROOT/install-antonia.sh"
if ANTONIA_TEST_ROBOT_FAILURE=1 \
    ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
    "$FAILURE_ROOT/install-antonia.sh" > "$FAILURE_ROOT/install.log" 2>&1; then
  echo "Error: installation unexpectedly succeeded" >&2
  exit 1
fi
test -f "$FAILURE_ROOT/install-antonia.sh"
test ! -e "$FAILURE_ROOT/toolbox"
grep -q 'simulated ROBOT installation failure' "$FAILURE_ROOT/install.log"

echo "lifecycle scripts test: passed"
