#!/usr/bin/env bash
# ... header unchanged ...
set -euo pipefail
source "$(dirname "$0")/common.sh"   # ← charge config/config.env

# 1) Ensure classified ontology
CLASSIFIED="$TARGET/classified.ttl"
if [ ! -f "$CLASSIFIED" ]; then
  echo "▶ No classified ontology found → running reason.sh"
  "$(dirname "$0")/reason.sh"
else
  echo "▶ Using existing classified ontology: ${CLASSIFIED#$ROOT/}"
fi
mkdir -p "$TARGET"

# 2) OWL profile validation (DL/EL/QL/RL only)
PROFILE="${OWL_PROFILE:-DL}"   # vient de config/config.env via common.sh
case "$PROFILE" in
  DL|EL|QL|RL) : ;;  # ok
  *) echo "✖ Invalid OWL profile '$PROFILE' (allowed: DL|EL|QL|RL). Fix config/config.env (OWL_PROFILE=...)."; exit 1;;
esac

OUTFILE="$TARGET/profile-validation.txt"
DL_VIEW="$TARGET/classified_dlview.ttl"

robot query \
  --input "$CLASSIFIED" \
  --update "$ROOT/src/sparql/updates/fix-dl-profile.ru" \
  --output "$DL_VIEW"

echo "▶ Validating ontology profile ($PROFILE)"
robot validate-profile \
  --input "$DL_VIEW" \
  --profile "$PROFILE" \
  --output "$OUTFILE" \
  || { echo "✖ OWL $PROFILE profile validation failed (see ${OUTFILE#$ROOT/} if created)"; exit 1; }

echo "✓ Ontology validation completed"
echo "  - Profile validation: ${OUTFILE#$ROOT/}"

