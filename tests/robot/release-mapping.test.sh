#!/usr/bin/env bash
# Verify Ontop, QL, and RDF mapping publication without datasource secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-release-mapping.XXXXXX)"
ORIGIN="$TEMP_ROOT/origin.git"
WORK="$TEMP_ROOT/work"
FAKE_BIN="$TEMP_ROOT/bin"
GH_LOG="$TEMP_ROOT/gh.log"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-release-mapping.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$WORK/toolbox" "$WORK/config" "$WORK/src/edit/mappings" \
  "$WORK/src/edit/services" "$WORK/tmp" "$FAKE_BIN"
git init -q --bare "$ORIGIN"
git -C "$WORK" init -q
git -C "$WORK" checkout -q -b main
git -C "$WORK" config user.name "ANTONIA Test"
git -C "$WORK" config user.email "antonia-test@example.invalid"
git -C "$WORK" remote add origin "$ORIGIN"

cp "$ROOT/toolbox/release.sh" "$WORK/toolbox/release.sh"
cp "$ROOT/toolbox/common.sh" "$WORK/toolbox/common.sh"
cp "$ROOT/toolbox/templates/config/config.env" "$WORK/config/config.env"
sed -i.bak \
  -e 's|^MAPPINGS=.*|MAPPINGS=src/edit/mappings/source-to-target.rdf|' \
  -e 's|^ONTOLOGY_NAME=.*|ONTOLOGY_NAME=test-ontology|' \
  -e 's|^RELEASE_TAG_PREFIX=.*|RELEASE_TAG_PREFIX=test-v|' \
  "$WORK/config/config.env"
rm "$WORK/config/config.env.bak"

printf '%s\n' 'classified ontology' > "$WORK/tmp/classified.rdf"
printf '%s\n' 'merged ontology' > "$WORK/tmp/merged.rdf"
printf '%s\n' 'ontop ql ontology' > "$WORK/tmp/ontop-ql.rdf"
printf '%s\n' 'base ontology' > "$WORK/src/edit/myOntology-tbox.rdf"
printf '%s\n' 'validated obda mapping' > "$WORK/src/edit/myOntology-tbox.obda"
printf '%s\n' \
  '# internal endpoint must not be published' \
  'jdbc.url=jdbc:postgresql://internal.example:5432/secret' \
  'jdbc.user=release-test-user' \
  'jdbc.password=release-test-password' \
  'jdbc.driver=org.postgresql.Driver' \
  > "$WORK/src/edit/myOntology.properties"
printf '%s\n' 'mapping ontology with exact bytes' \
  > "$WORK/src/edit/mappings/source-to-target.rdf"
printf '%s\n' 'already prefixed mapping with exact bytes' \
  > "$WORK/src/edit/mappings/mapping-reviewed.ttl"
printf '%s\n' 'password=must-never-be-published' \
  > "$WORK/src/edit/mappings/mapping-secret.properties"
printf '%s\n' 'tmp/' 'src/edit/**/*.properties' > "$WORK/.gitignore"

cat > "$FAKE_BIN/robot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=""
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --input) input="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$input" "$output"
EOF

cat > "$FAKE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
EOF
chmod +x "$WORK/toolbox/release.sh" "$FAKE_BIN/robot" "$FAKE_BIN/gh"

git -C "$WORK" add .gitignore config src toolbox
git -C "$WORK" commit -q -m "test mapping publication"
git -C "$WORK" push -q -u origin main

(
  cd "$WORK"
  PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" VERSION_TAG=2026-10-05 \
    ./toolbox/release.sh > "$TEMP_ROOT/release.log"
)

CURRENT_MAPPING="$WORK/releases/mapping-source-to-target.rdf"
ARCHIVE_MAPPING="$WORK/releases/archive/2026-10-05/mapping-source-to-target.rdf"
cmp "$WORK/src/edit/mappings/source-to-target.rdf" "$CURRENT_MAPPING"
cmp "$WORK/src/edit/mappings/source-to-target.rdf" "$ARCHIVE_MAPPING"
grep -Fq "$ARCHIVE_MAPPING" "$GH_LOG"

CURRENT_PREFIXED="$WORK/releases/mapping-reviewed.ttl"
ARCHIVE_PREFIXED="$WORK/releases/archive/2026-10-05/mapping-reviewed.ttl"
cmp "$WORK/src/edit/mappings/mapping-reviewed.ttl" "$CURRENT_PREFIXED"
cmp "$WORK/src/edit/mappings/mapping-reviewed.ttl" "$ARCHIVE_PREFIXED"
grep -Fq "$ARCHIVE_PREFIXED" "$GH_LOG"

cmp "$WORK/src/edit/myOntology-tbox.rdf" "$WORK/releases/test-ontology.rdf"
cmp "$WORK/src/edit/myOntology-tbox.rdf" \
  "$WORK/releases/archive/2026-10-05/test-ontology.rdf"
cmp "$WORK/tmp/merged.rdf" "$WORK/releases/test-ontology-merged.rdf"
cmp "$WORK/tmp/merged.rdf" \
  "$WORK/releases/archive/2026-10-05/test-ontology-merged.rdf"
cmp "$WORK/tmp/ontop-ql.rdf" "$WORK/releases/test-ontology-ql.rdf"
cmp "$WORK/tmp/ontop-ql.rdf" \
  "$WORK/releases/archive/2026-10-05/test-ontology-ql.rdf"
grep -Fq "$WORK/releases/archive/2026-10-05/test-ontology-ql.rdf" "$GH_LOG"
cmp "$WORK/src/edit/myOntology-tbox.obda" \
  "$WORK/releases/test-ontology.obda"
cmp "$WORK/src/edit/myOntology-tbox.obda" \
  "$WORK/releases/archive/2026-10-05/test-ontology.obda"
grep -Fq "$WORK/releases/archive/2026-10-05/test-ontology.obda" "$GH_LOG"

printf '%s\n' \
  'jdbc.url=' \
  'jdbc.user=' \
  'jdbc.password=' \
  'jdbc.driver=' \
  > "$TEMP_ROOT/expected.properties.example"
cmp "$TEMP_ROOT/expected.properties.example" \
  "$WORK/releases/test-ontology.properties.example"
cmp "$TEMP_ROOT/expected.properties.example" \
  "$WORK/releases/archive/2026-10-05/test-ontology.properties.example"
grep -Fq "$WORK/releases/archive/2026-10-05/test-ontology.properties.example" \
  "$GH_LOG"
if find "$WORK/releases" -type f -exec grep -El \
    'internal\.example|release-test-user|release-test-password' {} + \
    | grep -q .; then
  echo "Error: datasource secret content was copied into a Release asset" >&2
  exit 1
fi
if find "$WORK/releases" -type f -name '*.properties' -print -quit \
    | grep -q .; then
  echo "Error: a real datasource .properties file was released" >&2
  exit 1
fi
if cmp -s "$WORK/tmp/classified.rdf" "$WORK/releases/test-ontology.rdf"; then
  echo "Error: the classified graph was published as the base ontology" >&2
  exit 1
fi

test ! -e "$WORK/releases/source-to-target.rdf"
test ! -e "$WORK/releases/mapping-mapping-reviewed.ttl"
test ! -e "$WORK/releases/mapping-secret.properties"
if grep -Fq 'mapping-secret.properties' "$GH_LOG"; then
  echo "Error: mapping properties file was attached to the GitHub Release" >&2
  exit 1
fi

echo "release mapping test: passed"
