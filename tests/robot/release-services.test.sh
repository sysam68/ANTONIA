#!/usr/bin/env bash
# Verify explicit service-catalog publication and exclusion of secret files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-release-services.XXXXXX)"
ORIGIN="$TEMP_ROOT/origin.git"
WORK="$TEMP_ROOT/work"
FAKE_BIN="$TEMP_ROOT/bin"
GH_LOG="$TEMP_ROOT/gh.log"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-release-services.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$WORK/toolbox" "$WORK/config" "$WORK/src/edit/mappings" \
  "$WORK/src/edit/services" \
  "$WORK/tmp" "$FAKE_BIN"
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
  -e 's|^TBOX=.*|TBOX=src/edit/base.ttl|' \
  -e 's|^ONTOLOGY_NAME=.*|ONTOLOGY_NAME=test-ontology|' \
  -e 's|^RELEASE_TAG_PREFIX=.*|RELEASE_TAG_PREFIX=test-v|' \
  "$WORK/config/config.env"
rm "$WORK/config/config.env.bak"

printf '%s\n' 'classified ontology' > "$WORK/tmp/classified.rdf"
printf '%s\n' 'merged ontology' > "$WORK/tmp/merged.rdf"
printf '%s\n' 'base ontology requiring RDF conversion' \
  > "$WORK/src/edit/base.ttl"
printf '%s\n' '@prefix dcat: <http://www.w3.org/ns/dcat#> .' \
  '<https://example.org/service/a> a dcat:DataService .' \
  > "$WORK/src/edit/services/catalog-a.ttl"
printf '%s\n' '<?xml version="1.0"?>' '<rdf:RDF/>' \
  > "$WORK/src/edit/services/service-already.rdf"
printf '%s\n' 'password=must-never-be-published' \
  > "$WORK/src/edit/services/service-secret.properties"
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
: > "$GH_LOG"

git -C "$WORK" add .gitignore config src toolbox
git -C "$WORK" commit -q -m "test automatic service publication"
git -C "$WORK" push -q -u origin main

(
  cd "$WORK"
  PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" VERSION_TAG=2026-10-06 \
    ./toolbox/release.sh > "$TEMP_ROOT/release.log"
)

cmp "$WORK/src/edit/services/catalog-a.ttl" \
  "$WORK/releases/service-catalog-a.ttl"
cmp "$WORK/src/edit/services/catalog-a.ttl" \
  "$WORK/releases/archive/2026-10-06/service-catalog-a.ttl"
grep -Fq "$WORK/releases/archive/2026-10-06/service-catalog-a.ttl" "$GH_LOG"

cmp "$WORK/src/edit/services/service-already.rdf" \
  "$WORK/releases/service-already.rdf"
cmp "$WORK/src/edit/services/service-already.rdf" \
  "$WORK/releases/archive/2026-10-06/service-already.rdf"
grep -Fq "$WORK/releases/archive/2026-10-06/service-already.rdf" "$GH_LOG"

cmp "$WORK/src/edit/base.ttl" "$WORK/releases/test-ontology.rdf"
cmp "$WORK/src/edit/base.ttl" \
  "$WORK/releases/archive/2026-10-06/test-ontology.rdf"
cmp "$WORK/src/edit/base.ttl" "$WORK/releases/test-ontology.owl"
cmp "$WORK/tmp/merged.rdf" "$WORK/releases/test-ontology-merged.rdf"
if cmp -s "$WORK/tmp/classified.rdf" "$WORK/releases/test-ontology.rdf"; then
  echo "Error: the classified graph was published as the base ontology" >&2
  exit 1
fi

test ! -e "$WORK/releases/catalog-a.ttl"
test ! -e "$WORK/releases/service-service-already.rdf"
test ! -e "$WORK/releases/service-secret.properties"
if find "$WORK/releases" -type f -exec grep -Fl 'must-never-be-published' {} + \
    | grep -q .; then
  echo "Error: secret content was copied into a Release asset" >&2
  exit 1
fi
if grep -Fq 'service-secret.properties' "$GH_LOG"; then
  echo "Error: secret properties file was attached to the GitHub Release" >&2
  exit 1
fi
echo "release services test: passed"
