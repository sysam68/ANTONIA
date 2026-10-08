#!/usr/bin/env bash
# Verify Make targets and the intentionally consolidated ANTONIA skill set.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
MAKEFILE="$ROOT/toolbox/Makefile"
AGENT_ROOT="$ROOT/toolbox/.agents"
MANIFEST="$AGENT_ROOT/.antonia-managed"

EXPECTED_TARGETS="help
all
import
install-robot
install-semantic-tools
update-antonia
generate
reason
project-ql
report
validate
test-imports
test-qc
test-profiles
test-equivalences
test-release
release
diff
clean
init-x
progress
java-conf
init-project"

ACTUAL_TARGETS="$(awk -F: '/^[A-Za-z0-9][A-Za-z0-9_-]*:/ { print $1 }' \
  "$MAKEFILE" | LC_ALL=C sort)"
SORTED_EXPECTED_TARGETS="$(printf '%s\n' "$EXPECTED_TARGETS" | LC_ALL=C sort)"

if [ "$ACTUAL_TARGETS" != "$SORTED_EXPECTED_TARGETS" ]; then
  echo "Error: ANTONIA skill coverage is not aligned with toolbox/Makefile." >&2
  echo "Expected targets:" >&2
  printf '%s\n' "$SORTED_EXPECTED_TARGETS" >&2
  echo "Actual targets:" >&2
  printf '%s\n' "$ACTUAL_TARGETS" >&2
  exit 1
fi

while IFS=' ' read -r target skill_name; do
  [ -n "$target" ] || continue
  skill_path="skills/$skill_name"
  skill_file="$AGENT_ROOT/$skill_path/SKILL.md"

  grep -Fqx "skill=$skill_path" "$MANIFEST"
  test -f "$skill_file"
  grep -Fqx "name: $skill_name" "$skill_file"
  grep -Fq "make $target" "$skill_file"
done <<'EOF'
help antonia-help
import antonia-import
install-robot antonia-install-robot
install-semantic-tools antonia-install-semantic-tools
update-antonia antonia-update
test-imports antonia-test-imports
test-qc antonia-test-qc
test-profiles antonia-test-profiles
test-equivalences antonia-test-equivalences
test-release antonia-test-release
release antonia-release
diff antonia-diff
clean antonia-clean
init-x antonia-init-x
java-conf antonia-java-conf
init-project antonia-init-project
EOF

STEWARD_PATH="skills/antonia-onto-steward"
STEWARD_FILE="$AGENT_ROOT/$STEWARD_PATH/SKILL.md"
grep -Fqx "skill=$STEWARD_PATH" "$MANIFEST"
test -f "$STEWARD_FILE"
grep -Fqx 'name: antonia-onto-steward' "$STEWARD_FILE"
grep -Fq 'single skill responsible for the complete `make all`' "$STEWARD_FILE"
for stage in generate reason project-ql report validate; do
  grep -Fq "\`$stage\`" "$STEWARD_FILE"
done

grep -Fq 'Do not run `make all` or any of its individual pipeline stages.' \
  "$AGENT_ROOT/skills/antonia-ontologist/SKILL.md"

while IFS= read -r removed_skill; do
  [ -n "$removed_skill" ] || continue
  if grep -Fqx "skill=skills/$removed_skill" "$MANIFEST"; then
    echo "Error: redundant pipeline skill remains managed: $removed_skill" >&2
    exit 1
  fi
  if [ -e "$AGENT_ROOT/skills/$removed_skill" ]; then
    echo "Error: redundant pipeline skill directory remains: $removed_skill" >&2
    exit 1
  fi
done <<'EOF'
antonia-ontology-workflow
antonia-all
antonia-generate
antonia-reason
antonia-project-ql
antonia-report
antonia-validate
antonia-progress
EOF

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    skill=*)
      skill_path="${line#skill=}"
      skill_name="${skill_path##*/}"
      skill_file="$AGENT_ROOT/$skill_path/SKILL.md"
      test -f "$skill_file"
      grep -Fqx "name: $skill_name" "$skill_file"
      grep -Eq '^description: .+' "$skill_file"
      ;;
  esac
done < "$MANIFEST"

for skill_directory in "$AGENT_ROOT"/skills/*; do
  skill_name="$(basename "$skill_directory")"
  grep -Fqx "skill=skills/$skill_name" "$MANIFEST"
done

INIT_X_DRY_RUN="$(make -f "$MAKEFILE" -n init-x)"
printf '%s\n' "$INIT_X_DRY_RUN" | grep -Fq 'chmod +x toolbox/*.sh'

while IFS= read -r script; do
  if [ ! -f "$ROOT/$script" ]; then
    test -f "$ROOT/${script#toolbox/}"
  fi
done < <(sed -n 's|^[[:space:]]*@\./\(toolbox/[A-Za-z0-9_.-]*\.sh\).*|\1|p' \
  "$MAKEFILE" | LC_ALL=C sort -u)

echo "agent skills test: passed"
