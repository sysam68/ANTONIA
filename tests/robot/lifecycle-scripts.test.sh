#!/usr/bin/env bash
# Verify bootstrap cleanup and in-toolbox lifecycle scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
RELEASE_ROOT="$(mktemp -d /tmp/antonia-lifecycle-release.XXXXXX)"
SUCCESS_ROOT="$(mktemp -d /tmp/antonia-lifecycle-success.XXXXXX)"
FAILURE_ROOT="$(mktemp -d /tmp/antonia-lifecycle-failure.XXXXXX)"
COLLISION_ROOT="$(mktemp -d /tmp/antonia-lifecycle-collision.XXXXXX)"

cleanup() {
  case "$RELEASE_ROOT" in
    /tmp/antonia-lifecycle-release.*) rm -rf -- "$RELEASE_ROOT" ;;
  esac
  case "$SUCCESS_ROOT" in
    /tmp/antonia-lifecycle-success.*) rm -rf -- "$SUCCESS_ROOT" ;;
  esac
  case "$FAILURE_ROOT" in
    /tmp/antonia-lifecycle-failure.*) rm -rf -- "$FAILURE_ROOT" ;;
  esac
  case "$COLLISION_ROOT" in
    /tmp/antonia-lifecycle-collision.*) rm -rf -- "$COLLISION_ROOT" ;;
  esac
}
trap cleanup EXIT

assert_managed_skills_installed() {
  local host_root="$1"
  local manifest="$host_root/.agents/.antonia-managed"
  local line=""
  local skill_path=""

  test -f "$manifest"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      skill=*)
        skill_path="${line#skill=}"
        test -f "$host_root/.agents/$skill_path/SKILL.md"
        ;;
    esac
  done < "$manifest"
}

assert_not_starting_with_backslash() {
  local path="$1"
  local first_byte=""

  test -s "$path"
  first_byte="$(LC_ALL=C od -An -tx1 -N1 "$path" | tr -d '[:space:]')"
  if [ "$first_byte" = "5c" ]; then
    echo "Error: initialized file starts with a literal backslash: $path" >&2
    exit 1
  fi
}

mkdir -p "$RELEASE_ROOT/stage"
tar -xzf "$ROOT/dist/antonia-toolbox.tar.gz" -C "$RELEASE_ROOT/stage"
cp "$ROOT/tests/data/install-robot-stub.sh" \
  "$RELEASE_ROOT/stage/toolbox/install_robot.sh"
chmod +x "$RELEASE_ROOT/stage/toolbox/install_robot.sh"
COPYFILE_DISABLE=1 tar -czf "$RELEASE_ROOT/antonia-toolbox.tar.gz" \
  -C "$RELEASE_ROOT/stage" toolbox
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$RELEASE_ROOT/antonia-toolbox.tar.gz" | awk '{ print $1 }' \
    > "$RELEASE_ROOT/antonia-toolbox.tar.gz.sha256"
else
  shasum -a 256 "$RELEASE_ROOT/antonia-toolbox.tar.gz" | awk '{ print $1 }' \
    > "$RELEASE_ROOT/antonia-toolbox.tar.gz.sha256"
fi

git -C "$SUCCESS_ROOT" init -q
printf 'project-specific-rule\n' > "$SUCCESS_ROOT/.gitignore"
cp "$ROOT/install-antonia.sh" "$SUCCESS_ROOT/install-antonia.sh"
ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/install-antonia.sh" > "$SUCCESS_ROOT/install.log"

test ! -e "$SUCCESS_ROOT/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
assert_managed_skills_installed "$SUCCESS_ROOT"
test -f "$SUCCESS_ROOT/.tools/install-robot-invoked"
test ! -e "$SUCCESS_ROOT/.tools/semantic"
grep -q '^install-semantic-tools:' "$SUCCESS_ROOT/Makefile"
grep -Fqx 'project-specific-rule' "$SUCCESS_ROOT/.gitignore"
test "$(grep -Fxc 'tmp/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc '.tools/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc 'src/edit/*.properties' "$SUCCESS_ROOT/.gitignore")" -eq 1
test -f "$SUCCESS_ROOT/src/edit/myOntology.properties.example"
for initialized_file in \
  "$SUCCESS_ROOT/qc/profile.txt" \
  "$SUCCESS_ROOT/src/edit/myOntology-tbox.rdf" \
  "$SUCCESS_ROOT/src/edit/mapping-sourceIOnto-TargetOnto.rdf" \
  "$SUCCESS_ROOT/src/sparql/checks/example_check.rq" \
  "$SUCCESS_ROOT/src/sparql/updates/project-ql.ru" \
  "$SUCCESS_ROOT/src/shapes/shacl/ontology-shapes.ttl"; do
  assert_not_starting_with_backslash "$initialized_file"
done
grep -q 'Installing the repository-local ROBOT toolchain' "$SUCCESS_ROOT/install.log"
grep -q 'Removed bootstrap installer: install-antonia.sh' "$SUCCESS_ROOT/install.log"

bash "$SUCCESS_ROOT/toolbox/init_project.sh" > "$SUCCESS_ROOT/reinit.log"
test "$(grep -Fxc 'tmp/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc '.tools/' "$SUCCESS_ROOT/.gitignore")" -eq 1
test "$(grep -Fxc 'src/edit/*.properties' "$SUCCESS_ROOT/.gitignore")" -eq 1

mkdir -p "$SUCCESS_ROOT/.agents/skills/project-specific-skill"
printf '%s\n' 'project-owned skill' \
  > "$SUCCESS_ROOT/.agents/skills/project-specific-skill/SKILL.md"
printf '%s\n' 'locally modified managed skill' \
  > "$SUCCESS_ROOT/.agents/skills/antonia-ontology-workflow/SKILL.md"

touch "$SUCCESS_ROOT/toolbox/stale-before-update"
ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" > "$SUCCESS_ROOT/update.log"

test ! -e "$SUCCESS_ROOT/toolbox/stale-before-update"
test -x "$SUCCESS_ROOT/toolbox/install-antonia.sh"
test -x "$SUCCESS_ROOT/toolbox/update-antonia.sh"
test -f "$SUCCESS_ROOT/.agents/skills/project-specific-skill/SKILL.md"
grep -q '^name: antonia-ontology-workflow$' \
  "$SUCCESS_ROOT/.agents/skills/antonia-ontology-workflow/SKILL.md"
assert_managed_skills_installed "$SUCCESS_ROOT"
grep -q 'ANTONIA toolbox updated:' "$SUCCESS_ROOT/update.log"

ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" > "$SUCCESS_ROOT/update-second.log"
test -f "$SUCCESS_ROOT/.agents/skills/project-specific-skill/SKILL.md"
grep -q '^name: antonia-ontology-workflow$' \
  "$SUCCESS_ROOT/.agents/skills/antonia-ontology-workflow/SKILL.md"
assert_managed_skills_installed "$SUCCESS_ROOT"

ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" -dev -version=test-dev.1 \
  > "$SUCCESS_ROOT/update-dev-version.log"
grep -Fq 'Downloading ANTONIA toolbox (test-dev.1, channel: dev)' \
  "$SUCCESS_ROOT/update-dev-version.log"

mkdir -p "$RELEASE_ROOT/bin"
cat > "$RELEASE_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
if [ "${1:-} ${2:-}" = "release list" ]; then
  printf '%s\n' 'test-dev.2'
  exit 0
fi
echo "unexpected gh invocation: $*" >&2
exit 2
EOF
chmod +x "$RELEASE_ROOT/bin/gh"
: > "$RELEASE_ROOT/gh.log"
PATH="$RELEASE_ROOT/bin:$PATH" GH_LOG="$RELEASE_ROOT/gh.log" \
  ANTONIA_VERSION="ignored-stable-pin" \
  ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
  "$SUCCESS_ROOT/toolbox/update-antonia.sh" -dev \
  > "$SUCCESS_ROOT/update-dev-latest.log"
grep -Fq 'Resolved latest ANTONIA dev pre-Release: test-dev.2' \
  "$SUCCESS_ROOT/update-dev-latest.log"
grep -Fq 'Downloading ANTONIA toolbox (test-dev.2, channel: dev)' \
  "$SUCCESS_ROOT/update-dev-latest.log"
grep -Fq 'release list --repo sysam68/ANTONIA' "$RELEASE_ROOT/gh.log"

git -C "$FAILURE_ROOT" init -q
cp "$ROOT/install-antonia.sh" "$FAILURE_ROOT/install-antonia.sh"
if ANTONIA_TEST_ROBOT_FAILURE=1 \
    ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
    "$FAILURE_ROOT/install-antonia.sh" > "$FAILURE_ROOT/install.log" 2>&1; then
  echo "Error: installation unexpectedly succeeded" >&2
  exit 1
fi
test -f "$FAILURE_ROOT/install-antonia.sh"
test ! -e "$FAILURE_ROOT/toolbox"
grep -q 'simulated ROBOT installation failure' "$FAILURE_ROOT/install.log"

git -C "$COLLISION_ROOT" init -q
mkdir -p "$COLLISION_ROOT/.agents/skills/antonia-ontology-workflow"
printf '%s\n' 'project-owned colliding skill' \
  > "$COLLISION_ROOT/.agents/skills/antonia-ontology-workflow/SKILL.md"
cp "$ROOT/install-antonia.sh" "$COLLISION_ROOT/install-antonia.sh"
if ANTONIA_RELEASE_BASE_URL="file://$RELEASE_ROOT" \
    "$COLLISION_ROOT/install-antonia.sh" \
    > "$COLLISION_ROOT/install.log" 2>&1; then
  echo "Error: installation unexpectedly replaced an unmanaged skill" >&2
  exit 1
fi
test -f "$COLLISION_ROOT/install-antonia.sh"
test ! -e "$COLLISION_ROOT/toolbox"
grep -Fqx 'project-owned colliding skill' \
  "$COLLISION_ROOT/.agents/skills/antonia-ontology-workflow/SKILL.md"
grep -q 'refusing to replace unmanaged skill' "$COLLISION_ROOT/install.log"

echo "lifecycle scripts test: passed"
