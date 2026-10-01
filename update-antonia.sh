#!/usr/bin/env bash
# Update an existing ANTONIA-managed toolbox from a stable or dev Release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$SCRIPT_DIR/install-antonia.sh"

usage() {
  cat <<'EOF'
Usage: ./toolbox/update-antonia.sh [-dev] [-version=<tag>]

Options:
  -dev, --dev      Use the latest development pre-Release published from dev.
  -version=<tag>   Use an explicit stable or development Release tag.
  --help           Show this help message.

Without options, the updater uses the latest stable GitHub Release.
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

if [ ! -x "$INSTALLER" ]; then
  echo "Error: executable installer not found: $INSTALLER" >&2
  exit 1
fi

exec "$INSTALLER" --update "$@"
