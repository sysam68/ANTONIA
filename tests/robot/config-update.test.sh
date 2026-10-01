#!/usr/bin/env bash
# Verify additive configuration migration and idempotence.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-config-update.XXXXXX)"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-config-update.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$TEMP_ROOT/toolbox" "$TEMP_ROOT/config"
cp -R "$ROOT/toolbox/." "$TEMP_ROOT/toolbox/"
cp "$ROOT/tests/data/config-update-existing.env" "$TEMP_ROOT/config/config.env"
cp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.before"

FIRST_OUTPUT="$TEMP_ROOT/first-update.log"
bash "$TEMP_ROOT/toolbox/update_config.sh" > "$FIRST_OUTPUT"

ORIGINAL_SIZE="$(wc -c < "$TEMP_ROOT/config/config.env.before" | tr -d ' ')"
head -c "$ORIGINAL_SIZE" "$TEMP_ROOT/config/config.env" \
  | cmp - "$TEMP_ROOT/config/config.env.before"

grep -q '^TBOX=src/edit/custom-tbox.rdf$' "$TEMP_ROOT/config/config.env"
grep -q '^REASONER=ELK$' "$TEMP_ROOT/config/config.env"
grep -q '^USE_GH=0$' "$TEMP_ROOT/config/config.env"
grep -q '^LEGACY_ONLY=keep-me$' "$TEMP_ROOT/config/config.env"
grep -q '^GH_CREATE_RELEASE=1$' "$TEMP_ROOT/config/config.env"
grep -q '^ONTOP_PROPERTIES=src/edit/myOntology.properties$' "$TEMP_ROOT/config/config.env"
grep -q '^ONTOGPT_ALLOW_EXTERNAL_LLM=0$' "$TEMP_ROOT/config/config.env"
grep -q '^DB_SAMPLE_TO_LLM=0$' "$TEMP_ROOT/config/config.env"
grep -q '^SHACL_FAIL_ON=VIOLATION$' "$TEMP_ROOT/config/config.env"
grep -q 'Existing variables: TBOX, REASONER, USE_GH' "$FIRST_OUTPUT"
grep -q 'No longer expected: LEGACY_ONLY' "$FIRST_OUTPUT"

cp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.after-first-update"
bash "$TEMP_ROOT/toolbox/update_config.sh" > "$TEMP_ROOT/second-update.log"
cmp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.after-first-update"
grep -q 'New variables:      none' "$TEMP_ROOT/second-update.log"

echo "config update test: passed"
