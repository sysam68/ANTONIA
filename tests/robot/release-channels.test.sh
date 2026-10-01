#!/usr/bin/env bash
# Verify stable Release and development pre-Release branch guards.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-release-channels.XXXXXX)"
ORIGIN="$TEMP_ROOT/origin.git"
WORK="$TEMP_ROOT/work"
FAKE_BIN="$TEMP_ROOT/bin"
GH_LOG="$TEMP_ROOT/gh.log"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-release-channels.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

mkdir -p "$WORK" "$FAKE_BIN"
git init -q --bare "$ORIGIN"
git -C "$WORK" init -q
git -C "$WORK" checkout -q -b main
git -C "$WORK" config user.name "ANTONIA Test"
git -C "$WORK" config user.email "antonia-test@example.invalid"
git -C "$WORK" remote add origin "$ORIGIN"

cp "$ROOT/release-antonia.sh" "$WORK/release-antonia.sh"
cat > "$WORK/package-antonia.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
printf 'archive for %s\n' "$1" > dist/antonia-toolbox.tar.gz
printf 'test-checksum\n' > dist/antonia-toolbox.tar.gz.sha256
EOF
cat > "$WORK/.gitignore" <<'EOF'
dist/
EOF
chmod +x "$WORK/release-antonia.sh" "$WORK/package-antonia.sh"
git -C "$WORK" add release-antonia.sh package-antonia.sh .gitignore
git -C "$WORK" commit -q -m "test release channels"
git -C "$WORK" push -q -u origin main

git -C "$WORK" checkout -q -b dev
printf 'development\n' > "$WORK/dev-marker"
git -C "$WORK" add dev-marker
git -C "$WORK" commit -q -m "test development branch"
git -C "$WORK" push -q -u origin dev

cat > "$FAKE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
if [ "${1:-} ${2:-}" = "release view" ]; then
  exit 1
fi
if [ "${1:-} ${2:-}" = "release create" ]; then
  exit 0
fi
echo "unexpected gh invocation: $*" >&2
exit 2
EOF
chmod +x "$FAKE_BIN/gh"

if PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" \
    "$WORK/release-antonia.sh" v9.0.0 \
    > "$TEMP_ROOT/stable-from-dev.log" 2>&1; then
  echo "Error: stable Release was accepted from dev" >&2
  exit 1
fi
grep -Fq 'must use the main branch' "$TEMP_ROOT/stable-from-dev.log"

PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" \
  "$WORK/release-antonia.sh" --prerelease v9.1.0-dev.1 \
  > "$TEMP_ROOT/prerelease.log"
grep -Fq 'ANTONIA pre-Release published: v9.1.0-dev.1' \
  "$TEMP_ROOT/prerelease.log"
grep -Fq -- 'release create v9.1.0-dev.1' "$GH_LOG"
grep -Fq -- '--target dev' "$GH_LOG"
grep -Fq -- '--prerelease' "$GH_LOG"
grep -Fq -- '--latest=false' "$GH_LOG"

git -C "$WORK" checkout -q main
if PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" \
    "$WORK/release-antonia.sh" --prerelease v9.1.0-dev.2 \
    > "$TEMP_ROOT/prerelease-from-main.log" 2>&1; then
  echo "Error: development pre-Release was accepted from main" >&2
  exit 1
fi
grep -Fq 'must use the dev branch' "$TEMP_ROOT/prerelease-from-main.log"

PATH="$FAKE_BIN:$PATH" GH_LOG="$GH_LOG" \
  "$WORK/release-antonia.sh" v9.0.0 \
  > "$TEMP_ROOT/stable.log"
grep -Fq 'ANTONIA Release published: v9.0.0' "$TEMP_ROOT/stable.log"
grep -Fq -- 'release create v9.0.0' "$GH_LOG"
grep -Fq -- '--target main' "$GH_LOG"

echo "release channels test: passed"
