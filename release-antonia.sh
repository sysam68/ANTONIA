#!/usr/bin/env bash
# Package and publish an ANTONIA stable Release or development pre-Release.

set -euo pipefail

CHANNEL="stable"
VERSION=""

usage() {
  cat >&2 <<'EOF'
Usage:
  ./release-antonia.sh <release-tag>
  ./release-antonia.sh --prerelease <release-tag>

Stable Releases must be published from main. Development pre-Releases must be
published from dev. In both cases, the branch must be clean and synchronized
exactly with its origin counterpart.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --prerelease|-dev) CHANNEL="dev" ;;
    --help|-h) usage; exit 0 ;;
    *)
      if [ -n "$VERSION" ]; then
        echo "Error: multiple release tags supplied." >&2
        usage
        exit 2
      fi
      VERSION="$argument"
      ;;
  esac
done

case "$VERSION" in
  *[!A-Za-z0-9._-]*|'')
    usage
    exit 2
    ;;
esac

if [ "$CHANNEL" = "dev" ]; then
  RELEASE_BRANCH="dev"
  RELEASE_KIND="pre-Release"
else
  RELEASE_BRANCH="main"
  RELEASE_KIND="Release"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"

command -v git >/dev/null 2>&1 || { echo "Error: git is required." >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "Error: GitHub CLI (gh) is required." >&2; exit 1; }

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "Error: commit or remove working-tree changes before publishing a release." >&2
  exit 1
fi

if [ "$(git branch --show-current)" != "$RELEASE_BRANCH" ]; then
  echo "Error: ANTONIA $RELEASE_KIND publications must use the $RELEASE_BRANCH branch." >&2
  exit 1
fi

git fetch --quiet origin "$RELEASE_BRANCH" --tags
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$RELEASE_BRANCH")" ]; then
  echo "Error: local $RELEASE_BRANCH must exactly match origin/$RELEASE_BRANCH." >&2
  exit 1
fi

"$ROOT/package-antonia.sh" "$VERSION"

HEAD_HASH="$(git rev-parse HEAD)"
LOCAL_TAG_HASH="$(git rev-parse -q --verify "refs/tags/$VERSION^{commit}" 2>/dev/null || true)"
REMOTE_TAG_EXISTS=0
if git ls-remote --exit-code --tags --refs origin "refs/tags/$VERSION" >/dev/null 2>&1; then
  REMOTE_TAG_EXISTS=1
fi

if [ -n "$LOCAL_TAG_HASH" ] && [ "$LOCAL_TAG_HASH" != "$HEAD_HASH" ]; then
  echo "Error: tag '$VERSION' already points to another commit." >&2
  exit 1
fi
if [ "$REMOTE_TAG_EXISTS" -eq 1 ] && [ -z "$LOCAL_TAG_HASH" ]; then
  echo "Error: remote tag '$VERSION' could not be verified locally." >&2
  exit 1
fi

if [ -z "$LOCAL_TAG_HASH" ]; then
  git tag -a "$VERSION" -m "ANTONIA toolbox $VERSION"
fi
if [ "$REMOTE_TAG_EXISTS" -eq 0 ]; then
  git push origin "$VERSION"
fi

if gh release view "$VERSION" --repo sysam68/ANTONIA >/dev/null 2>&1; then
  EXISTING_PRERELEASE="$(gh release view "$VERSION" --repo sysam68/ANTONIA \
    --json isPrerelease --jq '.isPrerelease')"
  if { [ "$CHANNEL" = "dev" ] && [ "$EXISTING_PRERELEASE" != "true" ]; } \
      || { [ "$CHANNEL" = "stable" ] && [ "$EXISTING_PRERELEASE" != "false" ]; }; then
    echo "Error: existing GitHub Release channel does not match $CHANNEL: $VERSION" >&2
    exit 1
  fi
  echo "ANTONIA $RELEASE_KIND already exists: $VERSION"
  exit 0
fi

if [ "$CHANNEL" = "dev" ]; then
  gh release create "$VERSION" \
    "$ROOT/dist/antonia-toolbox.tar.gz" \
    "$ROOT/dist/antonia-toolbox.tar.gz.sha256" \
    --repo sysam68/ANTONIA \
    --verify-tag \
    --target dev \
    --prerelease \
    --latest=false \
    --title "ANTONIA toolbox $VERSION (development)" \
    --generate-notes
else
  gh release create "$VERSION" \
    "$ROOT/dist/antonia-toolbox.tar.gz" \
    "$ROOT/dist/antonia-toolbox.tar.gz.sha256" \
    --repo sysam68/ANTONIA \
    --verify-tag \
    --target main \
    --title "ANTONIA toolbox $VERSION" \
    --generate-notes
fi

echo "ANTONIA $RELEASE_KIND published: $VERSION"
