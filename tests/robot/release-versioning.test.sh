#!/usr/bin/env bash
# Verify automatic zero-padded daily ontology Release versions.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-release-versioning.XXXXXX)"
ORIGIN="$TEMP_ROOT/origin.git"
WORK="$TEMP_ROOT/work"
FAKE_BIN="$TEMP_ROOT/bin"
GH_LOG="$TEMP_ROOT/gh.log"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-release-versioning.*) rm -rf -- "$TEMP_ROOT" ;;
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
  -e 's|^ONTOLOGY_NAME=.*|ONTOLOGY_NAME=test-ontology|' \
  -e 's|^RELEASE_TAG_PREFIX=.*|RELEASE_TAG_PREFIX=test-v|' \
  "$WORK/config/config.env"
rm "$WORK/config/config.env.bak"

printf '%s\n' 'base ontology' > "$WORK/src/edit/myOntology-tbox.rdf"
printf '%s\n' 'classified ontology' > "$WORK/tmp/classified.rdf"
printf '%s\n' 'merged ontology' > "$WORK/tmp/merged.rdf"
printf '%s\n' 'ontop ql ontology' > "$WORK/tmp/ontop-ql.rdf"
printf '%s\n' 'tmp/' > "$WORK/.gitignore"

cat > "$FAKE_BIN/date" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "+%F" ]; then
  printf '%s\n' "${FAKE_RELEASE_DATE:-2026-10-08}"
else
  /bin/date "$@"
fi
EOF

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
chmod +x "$WORK/toolbox/release.sh" "$FAKE_BIN/date" \
  "$FAKE_BIN/robot" "$FAKE_BIN/gh"
: > "$GH_LOG"

git -C "$WORK" add .gitignore config src toolbox
git -C "$WORK" commit -q -m "test automatic release versioning"
git -C "$WORK" push -q -u origin main

(
  cd "$WORK"
  PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" ./toolbox/release.sh \
    > "$TEMP_ROOT/release-000.log"
)

git -C "$WORK" show-ref --verify --quiet refs/tags/test-v2026-10-08.000
test -d "$WORK/releases/archive/2026-10-08.000"
grep -Fq 'Version tag:    2026-10-08.000' "$TEMP_ROOT/release-000.log"
grep -Fq 'release create test-v2026-10-08.000' "$GH_LOG"
if git -C "$WORK" show-ref --verify --quiet refs/tags/test-v2026-10-08; then
  echo "Error: automatic release created a legacy unsuffixed tag" >&2
  exit 1
fi

(
  cd "$WORK"
  PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" ./toolbox/release.sh \
    > "$TEMP_ROOT/release-001.log"
)

git -C "$WORK" show-ref --verify --quiet refs/tags/test-v2026-10-08.001
test -d "$WORK/releases/archive/2026-10-08.001"
grep -Fq 'Version tag:    2026-10-08.001' "$TEMP_ROOT/release-001.log"
grep -Fq 'release create test-v2026-10-08.001' "$GH_LOG"

# Treat a legacy unsuffixed daily tag as the historical first release, so the
# automatic sequence resumes at .001 rather than creating a duplicate .000.
git -C "$WORK" tag test-v2026-10-09
git -C "$WORK" push -q origin test-v2026-10-09
(
  cd "$WORK"
  PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" FAKE_RELEASE_DATE=2026-10-09 \
    ./toolbox/release.sh > "$TEMP_ROOT/release-legacy-001.log"
)

git -C "$WORK" show-ref --verify --quiet refs/tags/test-v2026-10-09.001
if git -C "$WORK" show-ref --verify --quiet refs/tags/test-v2026-10-09.000; then
  echo "Error: legacy daily tag was not counted as the first release" >&2
  exit 1
fi
grep -Fq 'Version tag:    2026-10-09.001' \
  "$TEMP_ROOT/release-legacy-001.log"

echo "release versioning test: passed"
