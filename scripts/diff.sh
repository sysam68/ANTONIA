#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# diff.sh
# Compare two ontology versions using ROBOT diff.
# Outputs:
#   - target/diff.html   (human-readable HTML report)
#   - target/diff.owl    (machine-readable OWL diff)
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/common.sh"

# ---------------------------
# Arguments
# ---------------------------
OLD_VERSION="${1:-}"
NEW_VERSION="${2:-}"

if [ -z "$OLD_VERSION" ] || [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 <old-ontology-file.ttl> <new-ontology-file.ttl>"
  echo "Both files must be accessible locally."
  exit 1
fi

if [ ! -f "$OLD_VERSION" ]; then
  echo "✖ Old ontology file not found: $OLD_VERSION"
  exit 1
fi
if [ ! -f "$NEW_VERSION" ]; then
  echo "✖ New ontology file not found: $NEW_VERSION"
  exit 1
fi

mkdir -p "$TARGET"

# ---------------------------
# Run ROBOT diff
# ---------------------------
echo "▶ Comparing ontologies:"
echo "   Old: $OLD_VERSION"
echo "   New: $NEW_VERSION"

robot diff \
  --left "$OLD_VERSION" \
  --right "$NEW_VERSION" \
  --output "$TARGET/diff.owl" \
  --html "$TARGET/diff.html"

echo "✓ Diff completed"
echo "  - HTML report: $TARGET/diff.html"
echo "  - OWL diff:    $TARGET/diff.owl"

