#!/usr/bin/env bash
# Update an existing ANTONIA-managed toolbox from a GitHub Release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$SCRIPT_DIR/install-antonia.sh"

if [ ! -x "$INSTALLER" ]; then
  echo "Error: executable installer not found: $INSTALLER" >&2
  exit 1
fi

exec "$INSTALLER" --update "$@"
