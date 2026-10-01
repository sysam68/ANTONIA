#!/usr/bin/env python3
"""Validate an RDF graph against every SHACL graph in a directory."""

from __future__ import annotations

import argparse
from pathlib import Path

from pyshacl import validate
from rdflib import Graph


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--shapes-dir", required=True, type=Path)
    parser.add_argument("--report-rdf", required=True, type=Path)
    parser.add_argument("--report-text", required=True, type=Path)
    parser.add_argument(
        "--fail-on",
        choices=("VIOLATION", "WARNING", "INFO", "NONE"),
        default="VIOLATION",
    )
    return parser.parse_args()


def load_shapes(directory: Path) -> Graph:
    graph = Graph()
    paths = sorted(
        path
        for pattern in ("*.ttl", "*.rdf", "*.owl")
        for path in directory.rglob(pattern)
        if path.is_file()
    )
    if not paths:
        raise ValueError(f"no SHACL files found under {directory}")
    for path in paths:
        graph.parse(path)
    return graph


def main() -> int:
    args = parse_args()
    if not args.data.is_file():
        raise SystemExit(f"data graph not found: {args.data}")
    if not args.shapes_dir.is_dir():
        raise SystemExit(f"SHACL directory not found: {args.shapes_dir}")

    allow_warnings = args.fail_on in {"VIOLATION", "NONE"}
    allow_infos = args.fail_on in {"VIOLATION", "WARNING", "NONE"}
    conforms, report_graph, report_text = validate(
        data_graph=str(args.data),
        shacl_graph=load_shapes(args.shapes_dir),
        inference="rdfs",
        abort_on_first=False,
        allow_warnings=allow_warnings,
        allow_infos=allow_infos,
        meta_shacl=True,
    )

    args.report_rdf.parent.mkdir(parents=True, exist_ok=True)
    args.report_text.parent.mkdir(parents=True, exist_ok=True)
    report_graph.serialize(destination=args.report_rdf, format="turtle")
    args.report_text.write_text(str(report_text), encoding="utf-8")
    print(report_text)
    return 0 if conforms or args.fail_on == "NONE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
