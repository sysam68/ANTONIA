#!/usr/bin/env python3
"""Install a project ROBOT control into configured ANTONIA paths."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shlex
import tempfile


ASSIGNMENT = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")
CONTROL_NAME = re.compile(r"^[A-Za-z0-9_-]+$")
SEVERITIES = ("ERROR", "WARN", "INFO")
SCOPES = ("project-source", "non-mapping-source", "post-reason")


def parse_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = ASSIGNMENT.match(line)
        if not match:
            continue
        name, raw_value = match.groups()
        lexer = shlex.shlex(raw_value, posix=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        try:
            tokens = list(lexer)
        except ValueError as exc:
            raise ValueError(f"invalid assignment at {path}:{number}: {exc}") from exc
        if len(tokens) > 1:
            raise ValueError(f"unsupported multi-token value at {path}:{number}")
        values[name] = tokens[0] if tokens else ""
    return values


def configured_path(root: Path, values: dict[str, str], name: str) -> Path:
    value = values.get(name, "")
    if not value:
        raise ValueError(f"missing or empty {name} in config/config.env")
    path = Path(value)
    return (path if path.is_absolute() else root / path).resolve()


def validate_query(path: Path) -> bytes:
    content = path.read_bytes()
    text = content.decode("utf-8")
    match = re.search(
        r"\bselect\b\s+(?:(?:distinct|reduced)\s+)?(.*?)\bwhere\b",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match or "*" in match.group(1):
        raise ValueError("query must use an explicit SELECT projection")
    variables = re.findall(r"[?$]([A-Za-z_][A-Za-z0-9_]*)", match.group(1))
    if variables != ["entity", "property", "value"]:
        raise ValueError(
            "query must project exactly ?entity ?property ?value; "
            f"found: {', '.join(variables) or 'none'}"
        )
    return content


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def upsert_profile(path: Path, name: str, severity: str, scope: str) -> None:
    row = f"{severity}\t{name}\t{scope}"
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    result: list[str] = []
    replaced = False
    for line in lines:
        fields = line.split("\t")
        if not line.lstrip().startswith("#") and len(fields) >= 2 and fields[1] == name:
            if not replaced:
                result.append(row)
                replaced = True
            continue
        result.append(line)
    if not replaced:
        result.append(row)
    atomic_write(path, ("\n".join(result) + "\n").encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="config/config.env", type=Path)
    parser.add_argument("--name", required=True)
    parser.add_argument("--severity", required=True, choices=SEVERITIES)
    parser.add_argument("--scope", required=True, choices=SCOPES)
    parser.add_argument("--query", required=True, type=Path)
    args = parser.parse_args()

    config = args.config.resolve()
    if not config.is_file():
        parser.error(f"configuration file not found: {config}")
    if not CONTROL_NAME.fullmatch(args.name):
        parser.error("control name must contain only letters, digits, '_' or '-'")
    if not args.query.is_file():
        parser.error(f"query file not found: {args.query}")

    try:
        values = parse_config(config)
        root = config.parent.parent
        checks = configured_path(root, values, "SPARQL_CHECKS")
        profile = configured_path(root, values, "PROFILE")
        query_content = validate_query(args.query)
    except (OSError, UnicodeError, ValueError) as exc:
        parser.error(str(exc))

    destination = checks / f"{args.name}.rq"
    if args.query.resolve() != destination.resolve():
        atomic_write(destination, query_content)
    upsert_profile(profile, args.name, args.severity, args.scope)
    try:
        control_display = destination.relative_to(root)
    except ValueError:
        control_display = destination
    try:
        profile_display = profile.relative_to(root)
    except ValueError:
        profile_display = profile
    print(f"control={control_display}")
    print(f"profile={profile_display}")
    print(f"activation={args.severity}\t{args.name}\t{args.scope}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
