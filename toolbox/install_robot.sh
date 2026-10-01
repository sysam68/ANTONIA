#!/usr/bin/env bash
# Install a repository-local ROBOT CLI and, when needed, a local Java 17 JDK.
# Generated tools live under .tools/, which is intentionally ignored by Git.
set -euo pipefail

# Resolve ROOT using common.sh logic (supports submodule mode)
source "$(dirname "$0")/common.sh"
TOOLS_DIR="$ROOT/.tools"
BIN_DIR="$TOOLS_DIR/bin"
ROBOT_VERSION="${ROBOT_VERSION:-1.9.10}"
DEFAULT_ROBOT_SHA256="16a73c074f3df359a7338a84b4e0788785fe06117f931bb9796e9619ea776105"
ROBOT_SHA256="${ROBOT_SHA256:-$DEFAULT_ROBOT_SHA256}"
ROBOT_DIR="$TOOLS_DIR/robot/$ROBOT_VERSION"
ROBOT_JAR="$ROBOT_DIR/robot.jar"
LOCAL_JAVA_DIR="$TOOLS_DIR/java/17"
INSTALL_LOCAL_JAVA="${INSTALL_LOCAL_JAVA:-auto}"

command -v curl >/dev/null 2>&1 || { echo "✖ curl is required" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "✖ tar is required" >&2; exit 1; }

case "$INSTALL_LOCAL_JAVA" in
  auto|always|never) ;;
  *) echo "✖ INSTALL_LOCAL_JAVA must be auto, always, or never" >&2; exit 1 ;;
esac

make_temp_dir() {
  local d
  if d="$(mktemp -d -t imd-tools.XXXXXX 2>/dev/null)"; then
    printf '%s\n' "$d"
    return
  fi
  mktemp -d "${TMPDIR:-/tmp}/imd-tools.XXXXXX"
}

java_major() {
  local java_bin="$1"
  local version
  version="$("$java_bin" -version 2>&1 | sed -n 's/.*version "\([^"]*\)".*/\1/p' | head -n1)" || return 1
  [ -n "$version" ] || return 1
  case "$version" in
    1.*) printf '%s\n' "$version" | cut -d. -f2 ;;
    *)   printf '%s\n' "$version" | cut -d. -f1 ;;
  esac
}

java_is_compatible() {
  local java_bin="$1"
  local major
  [ -x "$java_bin" ] || return 1
  major="$(java_major "$java_bin")" || return 1
  [ "$major" -ge 17 ]
}

local_java_bin() {
  if [ -x "$LOCAL_JAVA_DIR/Contents/Home/bin/java" ]; then
    printf '%s\n' "$LOCAL_JAVA_DIR/Contents/Home/bin/java"
  elif [ -x "$LOCAL_JAVA_DIR/bin/java" ]; then
    printf '%s\n' "$LOCAL_JAVA_DIR/bin/java"
  else
    return 1
  fi
}

install_local_java() {
  local os arch api_url archive extracted java_bin backup
  case "$(uname -s)" in
    Darwin) os="mac" ;;
    Linux)  os="linux" ;;
    *) echo "✖ Automatic Java installation supports macOS and Linux only" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64|amd64) arch="x64" ;;
    *) echo "✖ Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
  esac

  api_url="https://api.adoptium.net/v3/binary/latest/17/ga/$os/$arch/jdk/hotspot/normal/eclipse?project=jdk"
  archive="$TEMP_DIR/temurin17.tar.gz"
  extracted="$TEMP_DIR/temurin17"

  echo "▶ Downloading a repository-local Eclipse Temurin JDK 17"
  curl -fL --retry 3 --output "$archive" "$api_url"
  tar -tzf "$archive" >/dev/null
  mkdir -p "$extracted"
  tar -xzf "$archive" -C "$extracted" --strip-components=1

  if [ -x "$extracted/Contents/Home/bin/java" ]; then
    java_bin="$extracted/Contents/Home/bin/java"
  else
    java_bin="$extracted/bin/java"
  fi
  java_is_compatible "$java_bin" || { echo "✖ Downloaded JDK is not Java 17+" >&2; exit 1; }

  mkdir -p "$TOOLS_DIR/java"
  if [ -e "$LOCAL_JAVA_DIR" ]; then
    backup="$TOOLS_DIR/java/17.invalid.$(date +%Y%m%d-%H%M%S)"
    mv "$LOCAL_JAVA_DIR" "$backup"
    echo "ℹ Previous invalid local JDK moved to ${backup#$ROOT/}"
  fi
  mv "$extracted" "$LOCAL_JAVA_DIR"
}

install_robot_jar() {
  local url staged actual_sha
  url="https://github.com/ontodev/robot/releases/download/v${ROBOT_VERSION}/robot.jar"

  if [ -f "$ROBOT_JAR" ]; then
    actual_sha="$(shasum -a 256 "$ROBOT_JAR" | awk '{print $1}')"
    if [ "$actual_sha" = "$ROBOT_SHA256" ]; then
      echo "✓ ROBOT $ROBOT_VERSION already downloaded"
      return
    fi
    echo "ℹ Existing ROBOT jar has an unexpected checksum; replacing it"
  fi

  mkdir -p "$ROBOT_DIR"
  staged="$TEMP_DIR/robot.jar"
  echo "▶ Downloading ROBOT $ROBOT_VERSION"
  curl -fL --retry 3 --output "$staged" "$url"
  actual_sha="$(shasum -a 256 "$staged" | awk '{print $1}')"
  [ "$actual_sha" = "$ROBOT_SHA256" ] || {
    echo "✖ ROBOT checksum mismatch: expected $ROBOT_SHA256, got $actual_sha" >&2
    exit 1
  }
  mv -f "$staged" "$ROBOT_JAR"
}

write_wrappers() {
  mkdir -p "$BIN_DIR"

  if local_java_bin >/dev/null 2>&1; then
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'BIN_DIR="$(cd "$(dirname "$0")" && pwd)"' \
      'TOOLS_DIR="$(cd "$BIN_DIR/.." && pwd)"' \
      'if [ -x "$TOOLS_DIR/java/17/Contents/Home/bin/java" ]; then' \
      '  exec "$TOOLS_DIR/java/17/Contents/Home/bin/java" "$@"' \
      'fi' \
      'exec "$TOOLS_DIR/java/17/bin/java" "$@"' \
      > "$BIN_DIR/java"
  else
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      "exec \"$SYSTEM_JAVA\" \"\$@\"" \
      > "$BIN_DIR/java"
  fi
  chmod +x "$BIN_DIR/java"

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'BIN_DIR="$(cd "$(dirname "$0")" && pwd)"' \
    'TOOLS_DIR="$(cd "$BIN_DIR/.." && pwd)"' \
    'exec "$BIN_DIR/java" -jar "$TOOLS_DIR/robot/current/robot.jar" "$@"' \
    > "$BIN_DIR/robot"
  chmod +x "$BIN_DIR/robot"

  mkdir -p "$TOOLS_DIR/robot"
  ln -sfn "$ROBOT_VERSION" "$TOOLS_DIR/robot/current"
}

mkdir -p "$TOOLS_DIR"
TEMP_DIR="$(make_temp_dir)"
trap 'rm -rf "$TEMP_DIR"' EXIT

SYSTEM_JAVA="$(command -v java 2>/dev/null || true)"
if [ "$INSTALL_LOCAL_JAVA" = "always" ]; then
  install_local_java
elif local_java_bin >/dev/null 2>&1 && java_is_compatible "$(local_java_bin)"; then
  echo "✓ Repository-local Java $(java_major "$(local_java_bin)") already installed"
elif [ -n "$SYSTEM_JAVA" ] && java_is_compatible "$SYSTEM_JAVA"; then
  echo "✓ Using system Java $(java_major "$SYSTEM_JAVA") at $SYSTEM_JAVA"
elif [ "$INSTALL_LOCAL_JAVA" = "never" ]; then
  echo "✖ Java 17+ is required and INSTALL_LOCAL_JAVA=never" >&2
  exit 1
else
  install_local_java
fi

install_robot_jar
write_wrappers

export PATH="$BIN_DIR:$PATH"
robot --version
echo "✓ Local ROBOT toolchain installed under ${TOOLS_DIR#$ROOT/}"
echo "  Build commands automatically use ${BIN_DIR#$ROOT/}"
