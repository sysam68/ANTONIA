#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# release.sh
# Prepare current release files at releases/ (flat, fixed names)
# AND archive the same files under releases/archive/<DATE>/.
# Git-only flow:
#   - On DEV: create/push 'release/<DATE>' and (optionally) open PR to MAIN
#   - On MAIN: create and push annotated tag '<PREFIX><DATE>' (+ optional GH Release)
#
# No pipeline here (no reason/report/validate). Artifacts must already exist in TARGET.
# -----------------------------------------------------------------------------
set -euo pipefail

# Resolve ROOT using common.sh logic (supports submodule mode)
source "$(dirname "$0")/common.sh"   # loads config/config.env

# --- High-resolution timestamp (YYYYMMDD-HHMMSS-mmm) ---
timestamp_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import datetime as d
n = d.datetime.now()
print(n.strftime("%Y%m%d-%H%M%S-")+f"{int(n.microsecond/1000):03d}")
PY
  elif command -v python >/dev/null 2>&1; then
    python - <<'PY'
import datetime as d
n = d.datetime.now()
print(n.strftime("%Y%m%d-%H%M%S-")+f"{int(n.microsecond/1000):03d}")
PY
  else
    # Fallback: seconds precision
    date "+%Y%m%d-%H%M%S-000"
  fi
}

# ---- Config (from config.env) ----
MAIN_BRANCH="${GIT_MAIN_BRANCH:-main}"
DEV_BRANCH="${GIT_DEV_BRANCH:-dev}"
TAG_PREFIX="${RELEASE_TAG_PREFIX:-${ONTOLOGY_NAME}-v}"
USE_GH="${USE_GH:-1}"
GH_CREATE_RELEASE="${GH_CREATE_RELEASE:-1}"
GH_RELEASE_DRAFT="${GH_RELEASE_DRAFT:-0}"
GH_RELEASE_PRERELEASE="${GH_RELEASE_PRERELEASE:-0}"
GH_RELEASE_NOTES_FILE="${GH_RELEASE_NOTES_FILE:-}"

VERSION_TAG="${VERSION_TAG:-$(date +%F)}"
RELEASE_TAG="${TAG_PREFIX}${VERSION_TAG}"

# Paths
CURRENT_DIR="$RELEASES"                      # releases/
ARCHIVE_DIR="$RELEASES/archive/$VERSION_TAG" # releases/archive/<date>/
REL_BRANCH="build-$(timestamp_ms)"   # e.g. build-20240826-153012-123

# Inputs from TARGET (must already exist)
CLASSIFIED="$TARGET/classified.ttl"
MERGED="$TARGET/merged.ttl"
QC_TSV="$TARGET/qc_report.tsv"
QC_HTML="$TARGET/qc_report.html"
DIFF_HTML="$TARGET/diff.html"
DIFF_OWL="$TARGET/diff.owl"

ONTO="${ONTOLOGY_NAME}"

# ---- Helpers ----
abort() { echo "✖ $*" >&2; exit 1; }
require_clean_git() { [ -z "$(git status --porcelain)" ] || abort "Uncommitted changes detected."; }
current_branch() { git rev-parse --abbrev-ref HEAD; }
# (facultatif mais conseillé) Mets à jour la liste de tags distante pour éviter un cache local vieilli
git fetch --tags --quiet origin || true
# Return 0 if local tag exists
tag_exists_local() {
  git show-ref --tags --quiet -- "refs/tags/$1"
}

# Return 0 if remote tag exists (and only if it actually matches something)
tag_exists_remote() {
  # --refs: ignore peeled '^{}' lines; grep -q . ensures non-empty output
  git ls-remote --tags --refs origin "refs/tags/$1" | grep -q .
}

# Return 0 if tag exists locally or remotely
tag_exists_any() {
  tag_exists_local "$1" || tag_exists_remote "$1"
}

# GitHub PR URL opener (if gh missing)
open_pr_url_fallback() {
  local remote owner_repo url
  remote="$(git remote get-url origin || true)"
  owner_repo="$(echo "$remote" | sed -E 's#^git@github.com:(.*)\.git$#\1#; s#^https?://github.com/##; s#\.git$##')"
  [ -n "$owner_repo" ] || return 0
  url="https://github.com/${owner_repo}/compare/${MAIN_BRANCH}...${REL_BRANCH}?expand=1"
  echo "→ Opening PR URL: $url"
  (command -v open >/dev/null 2>&1 && open "$url") || true
}

# ---- Pre-flight ----
command -v git   >/dev/null 2>&1 || abort "git not found"
command -v robot >/dev/null 2>&1 || abort "robot not found (needed for convert)"
git rev-parse --git-dir >/dev/null 2>&1 || abort "Not a git repository"
require_clean_git

BRANCH="$(current_branch)"
echo "▶ Current branch: $BRANCH"
echo "▶ Version tag:    $VERSION_TAG"
echo "▶ Release tag:    $RELEASE_TAG"

# Ensure required build artifacts exist
[ -f "$CLASSIFIED" ] || abort "Missing $CLASSIFIED (build your ontology first)."
[ -f "$MERGED" ]     || abort "Missing $MERGED (build your ontology first)."

# ---- 1) Prepare CURRENT (releases/) and ARCHIVE (releases/archive/<date>/) ----
echo "▶ Preparing CURRENT and ARCHIVE trees"
mkdir -p "$CURRENT_DIR" "$ARCHIVE_DIR"

# Fixed names for CURRENT
CUR_TTL="$CURRENT_DIR/${ONTO}.ttl"
CUR_MERGED="$CURRENT_DIR/${ONTO}-merged.ttl"
CUR_OWL="$CURRENT_DIR/${ONTO}.owl"
CUR_QC_TSV="$CURRENT_DIR/${ONTO}_qc_report.tsv"
CUR_QC_HTML="$CURRENT_DIR/${ONTO}_qc_report.html"

# Fixed names for ARCHIVE snapshot
ARC_TTL="$ARCHIVE_DIR/${ONTO}.ttl"
ARC_MERGED="$ARCHIVE_DIR/${ONTO}-merged.ttl"
ARC_OWL="$ARCHIVE_DIR/${ONTO}.owl"
ARC_QC_TSV="$ARCHIVE_DIR/${ONTO}_qc_report.tsv"
ARC_QC_HTML="$ARCHIVE_DIR/${ONTO}_qc_report.html"

# Copy CURRENT
cp -f "$CLASSIFIED" "$CUR_TTL"
cp -f "$MERGED"     "$CUR_MERGED"
[ -f "$QC_TSV" ]   && cp -f "$QC_TSV"   "$CUR_QC_TSV"
[ -f "$QC_HTML" ]  && cp -f "$QC_HTML"  "$CUR_QC_HTML"
[ -f "$DIFF_HTML" ]&& cp -f "$DIFF_HTML" "$CURRENT_DIR/diff.html"
[ -f "$DIFF_OWL" ] && cp -f "$DIFF_OWL"  "$CURRENT_DIR/diff.owl"

# Copy ARCHIVE snapshot
cp -f "$CLASSIFIED" "$ARC_TTL"
cp -f "$MERGED"     "$ARC_MERGED"
[ -f "$QC_TSV" ]   && cp -f "$QC_TSV"   "$ARC_QC_TSV"
[ -f "$QC_HTML" ]  && cp -f "$QC_HTML"  "$ARC_QC_HTML"
[ -f "$DIFF_HTML" ]&& cp -f "$DIFF_HTML" "$ARCHIVE_DIR/diff.html"
[ -f "$DIFF_OWL" ] && cp -f "$DIFF_OWL"  "$ARCHIVE_DIR/diff.owl"

# Produce OWL (RDF/XML) for both CURRENT and ARCHIVE
robot convert --input "$CUR_TTL" --output "$CUR_OWL"      # format deduced from .owl
robot convert --input "$ARC_TTL" --output "$ARC_OWL"

echo "✓ CURRENT → $(cd "$CURRENT_DIR" && pwd)"
echo "✓ ARCHIVE → $(cd "$ARCHIVE_DIR" && pwd)"

# Stage changes
git add "$CURRENT_DIR" "$ARCHIVE_DIR"
git commit -m "Release ${ONTOLOGY_NAME} ${VERSION_TAG}: update CURRENT and archive snapshot" || echo "ℹ Nothing to commit"

# ---- 2) Git-only flow ----
if [ "$BRANCH" = "$DEV_BRANCH" ]; then
  echo "▶ On '${DEV_BRANCH}': creating/pushing '${REL_BRANCH}' and opening PR → '${MAIN_BRANCH}'"
  if git rev-parse --verify "$REL_BRANCH" >/dev/null 2>&1; then
    git checkout "$REL_BRANCH"
  else
    git checkout -b "$REL_BRANCH"
  fi

  # Push branch: if no upstream is set locally, set it; otherwise push normally
  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    # upstream already configured for current local branch
    git push
  else
    # first push from this local branch → set upstream
   git push -u origin "$REL_BRANCH"

  fi

  if [ "$USE_GH" -eq 1 ] && command -v gh >/dev/null 2>&1; then
    echo "▶ Creating Pull Request via gh"
    if ! PR_URL="$(gh pr create --base "$MAIN_BRANCH" --head "$REL_BRANCH" \
        --title "Release ${ONTOLOGY_NAME} ${VERSION_TAG}" \
        --body "Automated release PR for ${ONTOLOGY_NAME} ${VERSION_TAG}" 2>/dev/null)"; then
      echo "ℹ PR may already exist. Showing current PR URL (if any)…"
      PR_URL="$(gh pr view --json url -q .url || true)"
    fi
    echo "✓ PR: ${PR_URL:-(unknown)}"
    echo "ℹ After merge to '${MAIN_BRANCH}', run this script on '${MAIN_BRANCH}' to create the final tag (${RELEASE_TAG})."
  else
    echo "ℹ GitHub CLI disabled/not found."
    echo "   Open a PR from '${REL_BRANCH}' to '${MAIN_BRANCH}' in your forge UI."
    open_pr_url_fallback
    echo "   After merge, switch to '${MAIN_BRANCH}' and re-run this script to tag (${RELEASE_TAG})."
  fi

elif [ "$BRANCH" = "$MAIN_BRANCH" ]; then
  echo "▶ On '${MAIN_BRANCH}': preparing to tag '${RELEASE_TAG}'"

  # Si le tag existe déjà ET pointe sur HEAD (local ou remote), on considère OK (idempotent)
  HEAD_HASH="$(git rev-parse HEAD)"
  REMOTE_HASH="$(git ls-remote --tags --refs origin "refs/tags/$RELEASE_TAG" | awk '{print $1}' || true)"
  LOCAL_HASH="$(git rev-parse -q --verify "refs/tags/$RELEASE_TAG^{commit}" 2>/dev/null || true)"

  if { [ -n "$LOCAL_HASH" ] && [ "$LOCAL_HASH" = "$HEAD_HASH" ]; } \
    || { [ -n "$REMOTE_HASH" ] && [ "$REMOTE_HASH" = "$HEAD_HASH" ]; }; then
    echo "✓ Tag '${RELEASE_TAG}' already exists and points to HEAD → nothing to do."
    exit 0
  fi

  # Si le tag existe (ailleurs que HEAD), on auto-bump si demandé, sinon on échoue proprement
  AUTO_BUMP="${AUTO_BUMP:-0}"
  if tag_exists_any "$RELEASE_TAG"; then
    if [ "$AUTO_BUMP" -eq 1 ]; then
      echo "ℹ Tag '${RELEASE_TAG}' exists (not on HEAD). Auto-bumping…"
      base="${VERSION_TAG%%.*}"   # ex: 2025-08-26
      idx=1
      while tag_exists_any "${TAG_PREFIX}${base}.${idx}"; do
        idx=$((idx+1))
      done
      VERSION_TAG="${base}.${idx}"
      RELEASE_TAG="${TAG_PREFIX}${VERSION_TAG}"
      echo "→ Using bumped tag: ${RELEASE_TAG}"
    else
      echo "✖ Tag '${RELEASE_TAG}' already exists. Use VERSION_TAG=YYYY-MM-DD(.N) or set AUTO_BUMP=1."
      exit 1
    fi
  fi
  git tag -a "$RELEASE_TAG" -m "Release ${ONTOLOGY_NAME} ${VERSION_TAG}"
  git push origin "$RELEASE_TAG"
  echo "✓ Tag pushed: ${RELEASE_TAG}"

  # Optional: create a GitHub Release and attach ARCHIVE assets (immutable snapshot)
  if [ "$USE_GH" -eq 1 ] && command -v gh >/dev/null 2>&1 && [ "$GH_CREATE_RELEASE" -eq 1 ]; then
    echo "▶ Creating GitHub Release for '${RELEASE_TAG}' (assets from archive snapshot)"
    ASSETS=()
    [ -f "$ARC_TTL" ]      && ASSETS+=("$ARC_TTL")
    [ -f "$ARC_OWL" ]      && ASSETS+=("$ARC_OWL")
    [ -f "$ARC_MERGED" ]   && ASSETS+=("$ARC_MERGED")
    [ -f "$ARC_QC_TSV" ]   && ASSETS+=("$ARC_QC_TSV")
    [ -f "$ARC_QC_HTML" ]  && ASSETS+=("$ARC_QC_HTML")
    [ -f "$ARCHIVE_DIR/diff.html" ] && ASSETS+=("$ARCHIVE_DIR/diff.html")
    [ -f "$ARCHIVE_DIR/diff.owl" ]  && ASSETS+=("$ARCHIVE_DIR/diff.owl")

    TITLE="${ONTOLOGY_NAME} ${VERSION_TAG}"
    NOTES_ARGS=()
    if [ -n "$GH_RELEASE_NOTES_FILE" ] && [ -f "$GH_RELEASE_NOTES_FILE" ]; then
      NOTES_ARGS+=( --notes-file "$GH_RELEASE_NOTES_FILE" )
    else
      NOTES_ARGS+=( --notes "Automated release for ${ONTOLOGY_NAME} ${VERSION_TAG}" )
    fi

    [ "$GH_RELEASE_DRAFT" -eq 1 ] && DRAFT_FLAG="--draft" || DRAFT_FLAG=""
    [ "$GH_RELEASE_PRERELEASE" -eq 1 ] && PR_FLAG="--prerelease" || PR_FLAG=""

    gh release create "$RELEASE_TAG" "${ASSETS[@]}" \
      --title "$TITLE" $DRAFT_FLAG $PR_FLAG "${NOTES_ARGS[@]}"

    echo "✓ GitHub Release created: $RELEASE_TAG"
  else
    echo "ℹ GitHub Release creation skipped (USE_GH=0/gh missing/GH_CREATE_RELEASE=0)."
  fi

  echo "ℹ Optionally sync '${DEV_BRANCH}':"
  echo "   git checkout ${DEV_BRANCH} && git pull --ff-only && git merge --ff-only ${MAIN_BRANCH} && git push"

else
  echo "⚠ You are on branch '${BRANCH}'."
  echo "   - Switch to '${DEV_BRANCH}' to create a release branch and open a PR"
  echo "   - Or switch to '${MAIN_BRANCH}' to create the final tag '${RELEASE_TAG}'"
  exit 2
fi