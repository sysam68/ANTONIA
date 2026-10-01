#!/usr/bin/env python3
"""Reject malformed OntoGPT extraction envelopes before ontology authoring."""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if not args.output.is_file():
        raise SystemExit("OntoGPT output file was not created")
    try:
        document = yaml.safe_load(args.output.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise SystemExit(f"OntoGPT output is not valid YAML: {exc}") from exc
    if not isinstance(document, dict) or "extracted_object" not in document:
        raise SystemExit("OntoGPT output is missing extracted_object")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
