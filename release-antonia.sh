#!/usr/bin/env bash
# Package and publish an ANTONIA toolbox GitHub Release.

set -euo pipefail

VERSION="${1:-}"
case "$VERSION" in
  *[!A-Za-z0-9._-]*|'')
    echo "Usage: ./release-antonia.sh <release-tag>" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"

command -v git >/dev/null 2>&1 || { echo "Error: git is required." >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "Error: GitHub CLI (gh) is required." >&2; exit 1; }

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "Error: commit or remove working-tree changes before publishing a release." >&2
  exit 1
fi

if [ "$(git branch --show-current)" != "main" ]; then
  echo "Error: ANTONIA releases must be published from the main branch." >&2
  exit 1
fi

git fetch --quiet origin main --tags
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Error: local main must exactly match origin/main." >&2
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
  echo "ANTONIA release already exists: $VERSION"
  exit 0
fi

gh release create "$VERSION" \
  "$ROOT/dist/antonia-toolbox.tar.gz" \
  "$ROOT/dist/antonia-toolbox.tar.gz.sha256" \
  --repo sysam68/ANTONIA \
  --verify-tag \
  --title "ANTONIA toolbox $VERSION" \
  --generate-notes

echo "ANTONIA release published: $VERSION"
