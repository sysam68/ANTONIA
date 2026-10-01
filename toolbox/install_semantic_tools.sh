#!/usr/bin/env bash
# Install the repository-local semantic authoring toolchain used by ANTONIA
# skills. Nothing is installed globally; all state is kept below .tools/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TOOLS_DIR="$ROOT/.tools"
BIN_DIR="$TOOLS_DIR/bin"
DOWNLOAD_DIR="$TOOLS_DIR/downloads"

UV_VERSION="${UV_VERSION:-0.12.21}"
PYTHON_VERSION="${ANTONIA_PYTHON_VERSION:-3.12.12}"
ONTOGPT_VERSION="${ONTOGPT_VERSION:-1.2.0}"
PYSHACL_VERSION="${PYSHACL_VERSION:-0.30.1}"
PYTHON_DOCX_VERSION="${PYTHON_DOCX_VERSION:-1.2.0}"
PSYCOPG_VERSION="${PSYCOPG_VERSION:-3.2.10}"
PYMYSQL_VERSION="${PYMYSQL_VERSION:-1.1.2}"
ONTOP_VERSION="${ONTOP_VERSION:-5.5.0}"
POSTGRES_JDBC_VERSION="${POSTGRES_JDBC_VERSION:-42.7.13}"
MYSQL_JDBC_VERSION="${MYSQL_JDBC_VERSION:-9.6.0}"

ONTOP_SHA256="${ONTOP_SHA256:-430dff312e68e8ad41d26e6113160ca2365c28c4fe911926193000a33299458f}"
POSTGRES_JDBC_SHA256="${POSTGRES_JDBC_SHA256:-6e0e4cc2d8cae902084f8a2b18728b073a6fd9d1f87c9d8bff8f298c18185b93}"
MYSQL_JDBC_SHA256="${MYSQL_JDBC_SHA256:-66df1d453789dc8cb759a7dc17f58646893bf28483f262328650f170472a6ead}"

command -v curl >/dev/null 2>&1 || { echo "Error: curl is required" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "Error: tar is required" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "Error: unzip is required" >&2; exit 1; }

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "Error: sha256sum or shasum is required" >&2
    return 1
  fi
}

download_verified() {
  local url="$1"
  local destination="$2"
  local expected="$3"
  local staged actual

  mkdir -p "$(dirname "$destination")"
  if [ -f "$destination" ] && [ "$(sha256_file "$destination")" = "$expected" ]; then
    return 0
  fi

  staged="${destination}.download"
  curl --fail --location --silent --show-error --retry 3 --output "$staged" "$url"
  actual="$(sha256_file "$staged")"
  if [ "$actual" != "$expected" ]; then
    echo "Error: checksum mismatch for $url" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    return 1
  fi
  mv -f "$staged" "$destination"
}

platform_name() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="apple-darwin" ;;
    Linux) os="unknown-linux-gnu" ;;
    *) echo "Error: semantic tools support macOS and Linux only" >&2; return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64|amd64) arch="x86_64" ;;
    *) echo "Error: unsupported CPU architecture: $(uname -m)" >&2; return 1 ;;
  esac
  printf '%s-%s\n' "$arch" "$os"
}

uv_checksum() {
  case "$1" in
    aarch64-apple-darwin) printf '%s\n' 'b88bda573e566ef9bced66b155fe0408626fbbc053aee1c30ba686f0728c9447' ;;
    x86_64-apple-darwin) printf '%s\n' '2b336763b396ec6afa20c5a8b083538ca7402445b868311979d740a4344c17d8' ;;
    aarch64-unknown-linux-gnu) printf '%s\n' '030b69227b40af8c1981b7301793dc66e71ed3c796ea8688209dd268bd91ec51' ;;
    x86_64-unknown-linux-gnu) printf '%s\n' '23f02075b652bb1df64178cfae41b5caf160822e720e2663568f3f5d63bc52c0' ;;
    *) echo "Error: no uv checksum for platform $1" >&2; return 1 ;;
  esac
}

install_uv() {
  local platform archive uv_dir extracted_uv
  platform="$(platform_name)"
  archive="$DOWNLOAD_DIR/uv-${UV_VERSION}-${platform}.tar.gz"
  uv_dir="$TOOLS_DIR/uv/$UV_VERSION"

  if [ -x "$uv_dir/uv" ]; then
    return 0
  fi

  download_verified \
    "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${platform}.tar.gz" \
    "$archive" "$(uv_checksum "$platform")"
  mkdir -p "$uv_dir"
  tar -xzf "$archive" -C "$uv_dir"
  extracted_uv="$(find "$uv_dir" -type f -name uv -print -quit)"
  [ -n "$extracted_uv" ] || { echo "Error: uv binary missing from archive" >&2; exit 1; }
  if [ "$extracted_uv" != "$uv_dir/uv" ]; then
    cp "$extracted_uv" "$uv_dir/uv"
  fi
  chmod +x "$uv_dir/uv"
}

install_python_tools() {
  local uv_bin venv marker expected
  uv_bin="$TOOLS_DIR/uv/$UV_VERSION/uv"
  venv="$TOOLS_DIR/semantic"
  marker="$venv/.antonia-versions"

  export UV_PYTHON_INSTALL_DIR="$TOOLS_DIR/python"
  export UV_CACHE_DIR="$TOOLS_DIR/cache/uv"

  "$uv_bin" python install "$PYTHON_VERSION"
  if [ ! -x "$venv/bin/python" ]; then
    "$uv_bin" venv --python "$PYTHON_VERSION" "$venv"
  fi

  expected="python=$PYTHON_VERSION
ontogpt=$ONTOGPT_VERSION
pyshacl=$PYSHACL_VERSION
python-docx=$PYTHON_DOCX_VERSION
psycopg=$PSYCOPG_VERSION
pymysql=$PYMYSQL_VERSION"
  if [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$expected" ]; then
    "$uv_bin" pip install --python "$venv/bin/python" \
      "ontogpt==$ONTOGPT_VERSION" \
      "pyshacl==$PYSHACL_VERSION" \
      "python-docx==$PYTHON_DOCX_VERSION" \
      "psycopg[binary]==$PSYCOPG_VERSION" \
      "pymysql==$PYMYSQL_VERSION"
    printf '%s\n' "$expected" > "$marker"
  fi
}

install_ontop() {
  local archive ontop_dir pg_jar mysql_jar
  archive="$DOWNLOAD_DIR/ontop-cli-${ONTOP_VERSION}.zip"
  ontop_dir="$TOOLS_DIR/ontop/$ONTOP_VERSION"
  pg_jar="$DOWNLOAD_DIR/postgresql-${POSTGRES_JDBC_VERSION}.jar"
  mysql_jar="$DOWNLOAD_DIR/mysql-connector-j-${MYSQL_JDBC_VERSION}.jar"

  download_verified \
    "https://github.com/ontop/ontop/releases/download/ontop-${ONTOP_VERSION}/ontop-cli-${ONTOP_VERSION}.zip" \
    "$archive" "$ONTOP_SHA256"
  if [ ! -x "$ontop_dir/ontop" ]; then
    mkdir -p "$ontop_dir"
    unzip -q -o "$archive" -d "$ontop_dir"
    chmod +x "$ontop_dir/ontop"
  fi

  download_verified \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
    "$pg_jar" "$POSTGRES_JDBC_SHA256"
  download_verified \
    "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_JDBC_VERSION}/mysql-connector-j-${MYSQL_JDBC_VERSION}.jar" \
    "$mysql_jar" "$MYSQL_JDBC_SHA256"
  cp "$pg_jar" "$ontop_dir/jdbc/postgresql.jar"
  cp "$mysql_jar" "$ontop_dir/jdbc/mysql-connector-j.jar"
}

write_wrappers() {
  mkdir -p "$BIN_DIR"
  for command_name in python ontogpt pyshacl; do
    target="$TOOLS_DIR/semantic/bin/$command_name"
    [ -x "$target" ] || continue
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'BIN_DIR="$(cd "$(dirname "$0")" && pwd -P)"' \
      'TOOLS_DIR="$(cd "$BIN_DIR/.." && pwd -P)"' \
      "exec \"\$TOOLS_DIR/semantic/bin/$command_name\" \"\$@\"" \
      > "$BIN_DIR/$command_name"
    chmod +x "$BIN_DIR/$command_name"
  done

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'BIN_DIR="$(cd "$(dirname "$0")" && pwd -P)"' \
    'TOOLS_DIR="$(cd "$BIN_DIR/.." && pwd -P)"' \
    'export PATH="$BIN_DIR:$PATH"' \
    "exec \"\$TOOLS_DIR/ontop/$ONTOP_VERSION/ontop\" \"\$@\"" \
    > "$BIN_DIR/ontop"
  chmod +x "$BIN_DIR/ontop"
}

ensure_local_java() {
  if [ -x "$BIN_DIR/java" ] && "$BIN_DIR/java" -version >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing the ANTONIA local Java prerequisite"
  "$SCRIPT_DIR/install_robot.sh"
}

main() {
  mkdir -p "$TOOLS_DIR" "$BIN_DIR" "$DOWNLOAD_DIR"
  ensure_local_java
  export PATH="$BIN_DIR:$PATH"
  install_uv
  install_python_tools
  install_ontop
  write_wrappers

  ontogpt --version
  ontop --version
  pyshacl --version
  echo "Semantic toolchain installed under ${TOOLS_DIR#$ROOT/}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
