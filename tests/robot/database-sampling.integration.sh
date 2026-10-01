#!/usr/bin/env bash
# Live PostgreSQL/MySQL integration for ANTONIA metadata, sampling, and bootstrap.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-database-integration.XXXXXX)"
POSTGRES_CONTAINER="antonia-postgres-$$"
MYSQL_CONTAINER="antonia-mysql-$$"

cleanup() {
  docker stop "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true
  docker stop "$MYSQL_CONTAINER" >/dev/null 2>&1 || true
  case "$TEMP_ROOT" in
    /tmp/antonia-database-integration.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "Error: Docker is required" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Error: Docker daemon is not available" >&2; exit 1; }
test -x "$ROOT/.tools/bin/ontop" || { echo "Error: run make install-semantic-tools" >&2; exit 1; }
test -x "$ROOT/.tools/semantic/bin/python" || { echo "Error: semantic Python missing" >&2; exit 1; }

docker run --rm -d --name "$POSTGRES_CONTAINER" -P \
  -e POSTGRES_PASSWORD=antonia-test -e POSTGRES_DB=antonia \
  postgres:16-alpine >/dev/null
docker run --rm -d --name "$MYSQL_CONTAINER" -P \
  -e MYSQL_ROOT_PASSWORD=antonia-test -e MYSQL_DATABASE=antonia \
  mysql:8.4 >/dev/null

for attempt in $(seq 1 60); do
  docker exec "$POSTGRES_CONTAINER" pg_isready -U postgres -d antonia >/dev/null 2>&1 && break
  [ "$attempt" -lt 60 ] || { echo "Error: PostgreSQL did not become ready" >&2; exit 1; }
  sleep 1
done
for attempt in $(seq 1 90); do
  docker exec "$MYSQL_CONTAINER" mysqladmin ping -h localhost -pantonia-test --silent >/dev/null 2>&1 && break
  [ "$attempt" -lt 90 ] || { echo "Error: MySQL did not become ready" >&2; exit 1; }
  sleep 1
done

docker exec "$POSTGRES_CONTAINER" psql -U postgres -d antonia -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE customer (id integer PRIMARY KEY, name varchar(80) NOT NULL); INSERT INTO customer VALUES (1, '\''Alice'\''), (2, '\''Bob'\''), (3, '\''Carol'\'');' >/dev/null
docker exec "$MYSQL_CONTAINER" mysql -uroot -pantonia-test antonia \
  -e "CREATE TABLE customer (id integer PRIMARY KEY, name varchar(80) NOT NULL); INSERT INTO customer VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Carol');" >/dev/null

POSTGRES_PORT="$(docker port "$POSTGRES_CONTAINER" 5432/tcp | sed 's/.*://')"
MYSQL_PORT="$(docker port "$MYSQL_CONTAINER" 3306/tcp | sed 's/.*://')"

printf '%s\n' \
  "jdbc.url=jdbc:postgresql://127.0.0.1:${POSTGRES_PORT}/antonia?currentSchema=public" \
  'jdbc.user=postgres' \
  'jdbc.password=antonia-test' \
  'jdbc.driver=org.postgresql.Driver' \
  > "$TEMP_ROOT/postgres.properties"
printf '%s\n' \
  "jdbc.url=jdbc:mysql://127.0.0.1:${MYSQL_PORT}/antonia?useSSL=false&allowPublicKeyRetrieval=true" \
  'jdbc.user=root' \
  'jdbc.password=antonia-test' \
  'jdbc.driver=com.mysql.cj.jdbc.Driver' \
  > "$TEMP_ROOT/mysql.properties"

for database in postgres mysql; do
  properties="$TEMP_ROOT/$database.properties"
  metadata="$TEMP_ROOT/$database-metadata.json"
  mapping="$TEMP_ROOT/$database.obda"
  ontology="$TEMP_ROOT/$database.owl"
  sample="$TEMP_ROOT/$database-sample.json"

  "$ROOT/.tools/bin/ontop" extract-db-metadata -p "$properties" -o "$metadata"
  "$ROOT/.tools/bin/ontop" bootstrap \
    -b "https://example.org/id/$database/" -p "$properties" \
    -m "$mapping" -t "$ontology"
  "$ROOT/.tools/bin/ontop" validate \
    -p "$properties" -m "$mapping" -t "$ontology"
  "$ROOT/.tools/semantic/bin/python" "$ROOT/toolbox/sample_database.py" \
    --properties "$properties" --tables customer --limit 2 --output "$sample"
  "$ROOT/.tools/semantic/bin/python" - "$metadata" "$sample" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text())
sample = json.loads(Path(sys.argv[2]).read_text())
assert metadata.get("relations"), "no database relations extracted"
assert len(sample["tables"]) == 1
assert sample["tables"][0]["table"] == "customer"
assert len(sample["tables"][0]["rows"]) == 2
PY
done

echo "database sampling integration test: passed"
