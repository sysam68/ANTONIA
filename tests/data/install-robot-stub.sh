#!/usr/bin/env bash
# Hermetic lifecycle-test replacement for the networked ROBOT installer.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [ "${ANTONIA_TEST_ROBOT_FAILURE:-0}" = "1" ]; then
  echo "simulated ROBOT installation failure" >&2
  exit 97
fi

mkdir -p "$ROOT/.tools"
touch "$ROOT/.tools/install-robot-invoked"
echo "test ROBOT toolchain installed"
