#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/antonia-import-release-test.XXXXXX")"
WORK="$TEST_ROOT/work"
BIN="$TEST_ROOT/bin"
GH_LOG="$TEST_ROOT/gh.log"
RELEASE_TAG="onto-v2099-01-02"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$WORK/toolbox" "$WORK/config" "$WORK/imports" "$BIN"
cp "$ROOT/toolbox/import.sh" "$WORK/toolbox/import.sh"

cat > "$WORK/config/config.env" <<'EOF'
IMPORTS_DIR=imports
EOF

cat > "$WORK/config/import.env" <<'EOF'
# repository#asset<TAB>release selector<TAB>local basename
https://github.com/example/ontology.git#ontology.rdf	latest	latest_import
git@github.com:example/ontology.git#ontology.rdf	onto-v2099-01-02	explicit_import
EOF

cat > "$TEST_ROOT/ontology.rdf" <<'EOF'
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>
EOF

cat > "$BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_LOG"

case "${1:-} ${2:-}" in
  "release view")
    printf '%s\n' "$FAKE_RELEASE_TAG"
    ;;
  "release download")
    shift 2
    test "${1:-}" = "$FAKE_RELEASE_TAG"
    shift
    output_dir=""
    asset_name=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --repo) shift 2 ;;
        --pattern) asset_name="$2"; shift 2 ;;
        --dir) output_dir="$2"; shift 2 ;;
        *) echo "Unexpected gh release download argument: $1" >&2; exit 2 ;;
      esac
    done
    test "$asset_name" = "ontology.rdf"
    cp "$FAKE_RELEASE_ASSET" "$output_dir/$asset_name"
    ;;
  *)
    echo "Unexpected gh invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$BIN/gh" "$WORK/toolbox/import.sh"

# A previous serialization must be removed when the Release asset is installed.
printf 'stale\n' > "$WORK/imports/latest_import.ttl"

(
  cd "$WORK"
  PATH="$BIN:$PATH" \
    FAKE_GH_LOG="$GH_LOG" \
    FAKE_RELEASE_TAG="$RELEASE_TAG" \
    FAKE_RELEASE_ASSET="$TEST_ROOT/ontology.rdf" \
    ./toolbox/import.sh
) > "$TEST_ROOT/import.log"

cmp "$TEST_ROOT/ontology.rdf" "$WORK/imports/latest_import.rdf"
cmp "$TEST_ROOT/ontology.rdf" "$WORK/imports/explicit_import.rdf"
test ! -e "$WORK/imports/latest_import.ttl"

# `latest` is resolved without passing a tag; explicit selectors are passed to
# `gh release view`. Both downloads use the resolved, concrete Release tag.
grep -Fxq 'release view --repo example/ontology --json tagName --jq .tagName' "$GH_LOG"
grep -Fxq "release view $RELEASE_TAG --repo example/ontology --json tagName --jq .tagName" "$GH_LOG"
test "$(grep -c "^release download $RELEASE_TAG " "$GH_LOG")" -eq 2
grep -Fq "GitHub Release example/ontology@$RELEASE_TAG:ontology.rdf" "$TEST_ROOT/import.log"

echo "ANTONIA GitHub Release import test passed"
