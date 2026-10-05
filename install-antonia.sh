#!/usr/bin/env bash
# Install or replace the ANTONIA toolbox from a published GitHub Release asset.

set -euo pipefail

readonly REPOSITORY="${ANTONIA_REPOSITORY:-sysam68/ANTONIA}"
readonly ASSET_NAME="antonia-toolbox.tar.gz"
readonly TOOLBOX_PATH="toolbox"

MODE="install"
CHANNEL="stable"
VERSION="${ANTONIA_VERSION:-latest}"
VERSION_ARGUMENT_SET=0
INIT_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./install-antonia.sh [--force] [-dev] [-version=<tag>]

Install the ANTONIA toolbox from the latest public GitHub Release.

Options:
  --force          Ask init_project.sh to overwrite project template files.
  -dev, --dev      Use the development pre-Release channel.
  -version=<tag>   Install an explicit stable or development Release tag.
  --help           Show this help message.

Environment variables:
  ANTONIA_VERSION           Release tag to install instead of "latest".
  ANTONIA_REPOSITORY        GitHub owner/repository (default: sysam68/ANTONIA).
  ANTONIA_RELEASE_BASE_URL  Asset directory override, mainly for mirrors/tests.
EOF
}

while [ "$#" -gt 0 ]; do
  argument="$1"
  case "$argument" in
    --update) MODE="update" ;;
    --force) INIT_ARGS+=("--force") ;;
    -dev|--dev) CHANNEL="dev" ;;
    -version=*|--version=*) VERSION="${argument#*=}"; VERSION_ARGUMENT_SET=1 ;;
    -version|--version)
      shift
      [ "$#" -gt 0 ] || { echo "Error: $argument requires a tag." >&2; usage >&2; exit 2; }
      VERSION="$1"
      VERSION_ARGUMENT_SET=1
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Error: unsupported argument: $argument" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# The explicit development channel always means "latest dev" unless its tag
# is supplied on the command line. ANTONIA_VERSION remains the stable-channel
# compatibility mechanism.
if [ "$CHANNEL" = "dev" ] && [ "$VERSION_ARGUMENT_SET" -eq 0 ]; then
  VERSION="latest"
fi

if [ "$MODE" = "update" ] && [ "${#INIT_ARGS[@]}" -ne 0 ]; then
  echo "Error: --force is only valid during initial installation." >&2
  exit 2
fi

for command_name in git curl tar; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: $command_name is required but was not found." >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
GIT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
BOOTSTRAP_INSTALLER=""

if [ -z "$GIT_ROOT" ]; then
  echo "Error: install-antonia.sh must be copied into a Git repository." >&2
  exit 1
fi

if [ "$SCRIPT_NAME" != "install-antonia.sh" ]; then
  echo "Error: the installer must be named install-antonia.sh." >&2
  exit 1
fi

if [ -f "$SCRIPT_DIR/.antonia-managed" ] && [ "$(basename "$SCRIPT_DIR")" = "$TOOLBOX_PATH" ]; then
  HOST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
  if [ "$HOST_ROOT" != "$GIT_ROOT" ]; then
    echo "Error: the managed toolbox is not directly under the Git repository root." >&2
    exit 1
  fi
else
  HOST_ROOT="$GIT_ROOT"
  if [ "$SCRIPT_DIR" != "$HOST_ROOT" ]; then
    echo "Error: the bootstrap installer must be located at the repository root." >&2
    echo "Expected: $HOST_ROOT/install-antonia.sh" >&2
    echo "Current:  $SCRIPT_DIR/install-antonia.sh" >&2
    exit 1
  fi
  BOOTSTRAP_INSTALLER="$HOST_ROOT/install-antonia.sh"
fi

if [ "$CHANNEL" = "dev" ] && [ "$VERSION" = "latest" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is required to resolve the latest dev pre-Release." >&2
    echo "Use -dev -version=<tag> to select a known tag without discovery." >&2
    exit 1
  fi
  # release-antonia.sh permits GitHub pre-Releases only from the synchronized
  # dev branch, so the newest non-draft pre-Release is the dev-channel head.
  VERSION="$(gh release list --repo "$REPOSITORY" --exclude-drafts --limit 100 \
    --json tagName,isPrerelease,publishedAt --jq \
    '[.[] | select(.isPrerelease == true)] | sort_by(.publishedAt) | last | .tagName // empty')"
  if [ -z "$VERSION" ]; then
    echo "Error: no ANTONIA development pre-Release was found for branch dev." >&2
    exit 1
  fi
  echo "Resolved latest ANTONIA dev pre-Release: $VERSION"
fi

case "$VERSION" in
  latest)
    if [ "$CHANNEL" != "stable" ]; then
      echo "Error: unresolved development pre-Release." >&2
      exit 1
    fi
    RELEASE_PATH="latest/download"
    ;;
  *[!A-Za-z0-9._-]*|'')
    echo "Error: invalid ANTONIA release tag: $VERSION" >&2
    exit 2
    ;;
  *) RELEASE_PATH="download/$VERSION" ;;
esac

if [ -n "${ANTONIA_RELEASE_BASE_URL:-}" ]; then
  RELEASE_DIRECTORY="${ANTONIA_RELEASE_BASE_URL%/}"
else
  RELEASE_DIRECTORY="https://github.com/$REPOSITORY/releases/$RELEASE_PATH"
fi

ARCHIVE_URL="$RELEASE_DIRECTORY/$ASSET_NAME"
CHECKSUM_URL="$ARCHIVE_URL.sha256"
DESTINATION="$HOST_ROOT/$TOOLBOX_PATH"

if [ "$MODE" = "install" ]; then
  if [ -e "$DESTINATION" ]; then
    echo "Error: '$DESTINATION' already exists." >&2
    echo "Run ./toolbox/update-antonia.sh to update a managed installation." >&2
    exit 1
  fi
else
  if [ ! -f "$DESTINATION/.antonia-managed" ]; then
    echo "Error: '$DESTINATION' is not an ANTONIA-managed toolbox." >&2
    echo "The directory was not modified." >&2
    exit 1
  fi
fi

TEMP_ROOT="$(mktemp -d "$HOST_ROOT/.antonia-install.XXXXXX")"
PREVIOUS_TOOLBOX=""
SWAP_COMPLETED=0

cleanup() {
  local status=$?

  if [ "$status" -ne 0 ] && [ "$MODE" = "install" ] \
      && [ "$SWAP_COMPLETED" -eq 1 ] \
      && [ -f "$DESTINATION/.antonia-managed" ]; then
    rm -rf -- "$DESTINATION"
  fi

  if [ "$status" -ne 0 ] && [ "$SWAP_COMPLETED" -eq 0 ] \
      && [ -n "$PREVIOUS_TOOLBOX" ] && [ -d "$PREVIOUS_TOOLBOX" ] \
      && [ ! -e "$DESTINATION" ]; then
    mv "$PREVIOUS_TOOLBOX" "$DESTINATION"
  fi

  case "$TEMP_ROOT" in
    "$HOST_ROOT"/.antonia-install.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

ARCHIVE="$TEMP_ROOT/$ASSET_NAME"
CHECKSUM="$ARCHIVE.sha256"
EXTRACTED="$TEMP_ROOT/extracted"

echo "Downloading ANTONIA toolbox ($VERSION, channel: $CHANNEL)"
curl --fail --location --silent --show-error --retry 3 \
  --output "$ARCHIVE" "$ARCHIVE_URL"
curl --fail --location --silent --show-error --retry 3 \
  --output "$CHECKSUM" "$CHECKSUM_URL"

EXPECTED_CHECKSUM="$(awk 'NR == 1 { print $1 }' "$CHECKSUM")"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_CHECKSUM="$(sha256sum "$ARCHIVE" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_CHECKSUM="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
else
  echo "Error: sha256sum or shasum is required to verify the release." >&2
  exit 1
fi

if [ -z "$EXPECTED_CHECKSUM" ] || [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
  echo "Error: ANTONIA release checksum verification failed." >&2
  exit 1
fi

while IFS= read -r entry; do
  case "$entry" in
    toolbox|toolbox/|toolbox/*) ;;
    *)
      echo "Error: unexpected path in release archive: $entry" >&2
      exit 1
      ;;
  esac
  case "/$entry/" in
    */../*|*/./*)
      echo "Error: unsafe path in release archive: $entry" >&2
      exit 1
      ;;
  esac
done < <(tar -tzf "$ARCHIVE")

mkdir -p "$EXTRACTED"
tar -xzf "$ARCHIVE" -C "$EXTRACTED"

CANDIDATE="$EXTRACTED/toolbox"
if [ ! -f "$CANDIDATE/.antonia-managed" ] \
    || [ ! -f "$CANDIDATE/Makefile" ] \
    || [ ! -f "$CANDIDATE/AGENTS.md" ] \
    || [ ! -f "$CANDIDATE/install-antonia.sh" ] \
    || [ ! -f "$CANDIDATE/update-antonia.sh" ] \
    || [ ! -f "$CANDIDATE/init_project.sh" ] \
    || [ ! -f "$CANDIDATE/install_robot.sh" ] \
    || [ ! -f "$CANDIDATE/install_semantic_tools.sh" ] \
    || [ ! -f "$CANDIDATE/common.sh" ] \
    || [ ! -f "$CANDIDATE/sync_agents.sh" ] \
    || [ ! -f "$CANDIDATE/update_config.sh" ] \
    || [ ! -f "$CANDIDATE/.agents/.antonia-managed" ] \
    || [ ! -f "$CANDIDATE/templates/config/config.env" ] \
    || [ ! -f "$CANDIDATE/checks/forbidden_iri.rq" ] \
    || [ ! -f "$CANDIDATE/checks/forbidden_equivalence.rq" ]; then
  echo "Error: incomplete or invalid ANTONIA toolbox release." >&2
  exit 1
fi

if find "$CANDIDATE" -type l -print -quit | grep -q .; then
  echo "Error: symbolic links are not allowed in the ANTONIA toolbox archive." >&2
  exit 1
fi

AGENT_MANIFEST="$CANDIDATE/.agents/.antonia-managed"
HOST_AGENT_MANIFEST="$HOST_ROOT/.agents/.antonia-managed"
if ! grep -Fqx 'format=1' "$AGENT_MANIFEST"; then
  echo "Error: invalid ANTONIA agent manifest format." >&2
  exit 1
fi
if ! grep -q '^skill=skills/' "$AGENT_MANIFEST"; then
  echo "Error: the ANTONIA agent manifest declares no skills." >&2
  exit 1
fi
if [ -f "$HOST_AGENT_MANIFEST" ]; then
  if ! grep -Fqx 'format=1' "$HOST_AGENT_MANIFEST"; then
    echo "Error: invalid installed ANTONIA agent manifest format." >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      format=1|'') ;;
      skill=skills/*)
        relative_path="${line#skill=}"
        case "${relative_path#skills/}" in
          ''|*/*|.*|*..*|*[!A-Za-z0-9._-]*)
            echo "Error: invalid installed managed skill path: $relative_path" >&2
            exit 1
            ;;
        esac
        ;;
      *)
        echo "Error: invalid installed ANTONIA agent manifest entry: $line" >&2
        exit 1
        ;;
    esac
  done < "$HOST_AGENT_MANIFEST"
fi
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    format=1|'') ;;
    skill=skills/*)
      relative_path="${line#skill=}"
      case "${relative_path#skills/}" in
        ''|*/*|.*|*..*|*[!A-Za-z0-9._-]*)
          echo "Error: invalid managed skill path: $relative_path" >&2
          exit 1
          ;;
      esac
      if [ ! -f "$CANDIDATE/.agents/$relative_path/SKILL.md" ]; then
        echo "Error: incomplete managed skill: $relative_path" >&2
        exit 1
      fi
      if [ -e "$HOST_ROOT/.agents/$relative_path" ] \
          && { [ ! -f "$HOST_AGENT_MANIFEST" ] \
            || ! grep -Fqx "skill=$relative_path" "$HOST_AGENT_MANIFEST"; }; then
        echo "Error: refusing to replace unmanaged skill: .agents/$relative_path" >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: invalid ANTONIA agent manifest entry: $line" >&2
      exit 1
      ;;
  esac
done < "$AGENT_MANIFEST"

INSTALLED_VERSION="$(awk -F= '$1 == "version" { print $2; exit }' "$CANDIDATE/.antonia-managed")"
if [ -z "$INSTALLED_VERSION" ]; then
  echo "Error: release version is missing from .antonia-managed." >&2
  exit 1
fi

if [ "$MODE" = "update" ]; then
  CURRENT_VERSION="$(awk -F= '$1 == "version" { print $2; exit }' "$DESTINATION/.antonia-managed")"
  PREVIOUS_TOOLBOX="$TEMP_ROOT/previous-toolbox"
  mv "$DESTINATION" "$PREVIOUS_TOOLBOX"
else
  CURRENT_VERSION="none"
fi

mv "$CANDIDATE" "$DESTINATION"
chmod +x "$DESTINATION"/*.sh
SWAP_COMPLETED=1

if [ "$MODE" = "install" ]; then
  echo "Initializing the ontology project"
  if [ "${#INIT_ARGS[@]}" -eq 0 ]; then
    bash "$DESTINATION/init_project.sh"
  else
    bash "$DESTINATION/init_project.sh" "${INIT_ARGS[@]}"
  fi
  echo "Installing the repository-local ROBOT toolchain"
  "$DESTINATION/install_robot.sh"
  echo "ANTONIA $INSTALLED_VERSION installed successfully."
  if [ -n "$BOOTSTRAP_INSTALLER" ] && [ -f "$BOOTSTRAP_INSTALLER" ]; then
    rm -- "$BOOTSTRAP_INSTALLER"
    echo "Removed bootstrap installer: install-antonia.sh"
  fi
else
  cp "$DESTINATION/Makefile" "$HOST_ROOT/Makefile"
  echo "Ontology Makefile updated from toolbox/Makefile"
  cp "$DESTINATION/AGENTS.md" "$HOST_ROOT/AGENTS.md"
  echo "Ontology AGENTS.md updated from toolbox/AGENTS.md"
  bash "$DESTINATION/sync_agents.sh"
  bash "$DESTINATION/update_config.sh"
  echo "ANTONIA toolbox updated: $CURRENT_VERSION -> $INSTALLED_VERSION"
fi
