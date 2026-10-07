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

mkdir -p "$TEMP_ROOT/toolbox" "$TEMP_ROOT/config" "$TEMP_ROOT/qc"
cp -R "$ROOT/toolbox/." "$TEMP_ROOT/toolbox/"
cp "$ROOT/tests/data/config-update-existing.env" "$TEMP_ROOT/config/config.env"
cp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.before"
printf '%s\n' \
  $'ERROR\tforbidden_iri' \
  $'WARN\tforbidden_equivalence' \
  $'ERROR\tproject_owned' \
  > "$TEMP_ROOT/qc/profile.txt"

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
grep -q '^OUTPUT_FORMAT=rdf' "$TEMP_ROOT/config/config.env"
grep -q '^MAPPINGS_DIR=src/edit/mappings$' "$TEMP_ROOT/config/config.env"
grep -q '^SERVICES_DIR=src/edit/services$' "$TEMP_ROOT/config/config.env"
if grep -Eq '^(PROJECT_SOURCE_CHECKS|NON_MAPPING_SOURCE_CHECKS)=' \
    "$TEMP_ROOT/config/config.env"; then
  echo "Error: control activation leaked into config.env" >&2
  exit 1
fi
grep -q 'Existing variables: TBOX, REASONER, USE_GH' "$FIRST_OUTPUT"
grep -q 'No longer expected: LEGACY_ONLY' "$FIRST_OUTPUT"
grep -Fqx $'ERROR\texample-forbidden_iri\tproject-source' \
  "$TEMP_ROOT/qc/profile.txt"
grep -Fqx $'WARN\texample-forbidden_equivalence\tnon-mapping-source' \
  "$TEMP_ROOT/qc/profile.txt"
grep -Fqx $'ERROR\tproject_owned' "$TEMP_ROOT/qc/profile.txt"
cmp "$TEMP_ROOT/toolbox/checks/example-forbidden_iri.rq" \
  "$TEMP_ROOT/src/sparql/checks/example-forbidden_iri.rq"
cmp "$TEMP_ROOT/toolbox/checks/example-forbidden_equivalence.rq" \
  "$TEMP_ROOT/src/sparql/checks/example-forbidden_equivalence.rq"
test ! -e "$TEMP_ROOT/src/sparql/checks/forbidden_iri.rq"
test ! -e "$TEMP_ROOT/src/sparql/checks/forbidden_equivalence.rq"
test -d "$TEMP_ROOT/src/edit/mappings"
test -d "$TEMP_ROOT/src/edit/services"
test "$(grep -Fxc 'src/edit/**/*.properties' "$TEMP_ROOT/.gitignore")" -eq 1

cp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.after-first-update"
cp "$TEMP_ROOT/qc/profile.txt" "$TEMP_ROOT/qc/profile.after-first-update"
bash "$TEMP_ROOT/toolbox/update_config.sh" > "$TEMP_ROOT/second-update.log"
cmp "$TEMP_ROOT/config/config.env" "$TEMP_ROOT/config/config.env.after-first-update"
cmp "$TEMP_ROOT/qc/profile.txt" "$TEMP_ROOT/qc/profile.after-first-update"
test -d "$TEMP_ROOT/src/edit/mappings"
test -d "$TEMP_ROOT/src/edit/services"
test "$(grep -Fxc 'src/edit/**/*.properties' "$TEMP_ROOT/.gitignore")" -eq 1
grep -q 'New variables:      none' "$TEMP_ROOT/second-update.log"

echo "config update test: passed"
