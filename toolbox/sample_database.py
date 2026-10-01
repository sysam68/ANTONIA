#!/usr/bin/env python3
"""Read a bounded, allowlisted sample using an Ontop JDBC properties file."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Optional, Tuple
from urllib.parse import parse_qsl, unquote, urlparse


IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_$]*$")


def load_properties(path: Path) -> dict[str, str]:
    properties: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("#", "!")):
            continue
        key, separator, value = line.partition("=")
        if not separator:
            key, separator, value = line.partition(":")
        if separator:
            properties[key.strip()] = value.strip()
    return properties


def split_table(name: str) -> Tuple[Optional[str], str]:
    parts = name.split(".")
    if len(parts) == 1:
        schema, table = None, parts[0]
    elif len(parts) == 2:
        schema, table = parts
    else:
        raise ValueError(f"invalid table name: {name}")
    for part in (schema, table):
        if part is not None and not IDENTIFIER.fullmatch(part):
            raise ValueError(f"unsafe table identifier: {name}")
    return schema, table


def parse_jdbc_url(value: str) -> Tuple[str, Any]:
    if value.startswith("jdbc:postgresql:"):
        parsed = urlparse(value.removeprefix("jdbc:"))
        return "postgresql", parsed
    if value.startswith("jdbc:mysql:"):
        parsed = urlparse(value.removeprefix("jdbc:"))
        return "mysql", parsed
    raise ValueError("only PostgreSQL and MySQL JDBC URLs are supported")


def connect(properties: dict[str, str]) -> Tuple[str, Any]:
    jdbc_url = properties.get("jdbc.url", "")
    user = properties.get("jdbc.user", "")
    password = properties.get("jdbc.password", "")
    database_type, parsed = parse_jdbc_url(jdbc_url)
    query = dict(parse_qsl(parsed.query))

    if database_type == "postgresql":
        import psycopg

        connection = psycopg.connect(
            host=parsed.hostname,
            port=parsed.port or 5432,
            dbname=unquote(parsed.path.lstrip("/")),
            user=user,
            password=password,
            connect_timeout=int(query.get("connectTimeout", "10")),
        )
        connection.autocommit = False
        connection.execute("SET TRANSACTION READ ONLY")
        return database_type, connection

    import pymysql

    connection = pymysql.connect(
        host=parsed.hostname or "localhost",
        port=parsed.port or 3306,
        database=unquote(parsed.path.lstrip("/")),
        user=user,
        password=password,
        connect_timeout=int(query.get("connectTimeout", "10")),
        read_timeout=30,
        write_timeout=30,
        autocommit=False,
    )
    with connection.cursor() as cursor:
        cursor.execute("SET TRANSACTION READ ONLY")
    return database_type, connection


def quote_identifier(database_type: str, value: str) -> str:
    quote = '"' if database_type == "postgresql" else "`"
    return f"{quote}{value}{quote}"


def json_value(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    return str(value)


def sample_table(database_type: str, connection: Any, table_name: str, limit: int) -> dict[str, Any]:
    schema, table = split_table(table_name)
    qualified = quote_identifier(database_type, table)
    if schema:
        qualified = f"{quote_identifier(database_type, schema)}.{qualified}"
    query = f"SELECT * FROM {qualified} LIMIT %s"
    with connection.cursor() as cursor:
        cursor.execute(query, (limit,))
        columns = [description[0] for description in cursor.description or ()]
        rows = [dict(zip(columns, map(json_value, row))) for row in cursor.fetchall()]
    return {"table": table_name, "columns": columns, "rows": rows}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--properties", required=True, type=Path)
    parser.add_argument("--tables", required=True, help="comma-separated allowlist")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not 1 <= args.limit <= 100:
        raise SystemExit("sample limit must be between 1 and 100")
    tables = [table.strip() for table in args.tables.split(",") if table.strip()]
    if not tables:
        raise SystemExit("no tables authorized for sampling")
    if not args.properties.is_file():
        raise SystemExit("Ontop properties file not found")

    database_type, connection = connect(load_properties(args.properties))
    try:
        result = {
            "database_type": database_type,
            "sample_limit": args.limit,
            "tables": [sample_table(database_type, connection, table, args.limit) for table in tables],
        }
    finally:
        connection.rollback()
        connection.close()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
