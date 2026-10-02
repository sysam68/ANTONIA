#!/usr/bin/env bash
# Validate both supported ontology products:
#   - expressive semantic reference: OWL 2 DL
#   - operational Ontop projection:  OWL 2 QL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/validate_dl.sh"
"$SCRIPT_DIR/validate_ql.sh"

echo "✓ OWL 2 DL and OWL 2 QL validations completed"
