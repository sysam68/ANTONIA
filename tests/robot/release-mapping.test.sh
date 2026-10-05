#!/usr/bin/env bash
# Verify that a configured RDF mapping is preserved and published separately.
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

mkdir -p "$WORK/toolbox" "$WORK/config" "$WORK/src/edit" "$WORK/tmp" "$FAKE_BIN"
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
  -e 's|^MAPPINGS=.*|MAPPINGS=src/edit/source-to-target.rdf|' \
  -e 's|^ONTOLOGY_NAME=.*|ONTOLOGY_NAME=test-ontology|' \
  -e 's|^RELEASE_TAG_PREFIX=.*|RELEASE_TAG_PREFIX=test-v|' \
  "$WORK/config/config.env"
rm "$WORK/config/config.env.bak"

printf '%s\n' 'classified ontology' > "$WORK/tmp/classified.rdf"
printf '%s\n' 'merged ontology' > "$WORK/tmp/merged.rdf"
printf '%s\n' 'mapping ontology with exact bytes' \
  > "$WORK/src/edit/source-to-target.rdf"
printf '%s\n' 'tmp/' > "$WORK/.gitignore"

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

CURRENT_MAPPING="$WORK/releases/source-to-target.rdf"
ARCHIVE_MAPPING="$WORK/releases/archive/2026-10-05/source-to-target.rdf"
cmp "$WORK/src/edit/source-to-target.rdf" "$CURRENT_MAPPING"
cmp "$WORK/src/edit/source-to-target.rdf" "$ARCHIVE_MAPPING"
grep -Fq "$ARCHIVE_MAPPING" "$GH_LOG"

echo "release mapping test: passed"
