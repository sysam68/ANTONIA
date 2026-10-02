#!/usr/bin/env bash
# Verify semantic skill distribution and deterministic helper guards.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d /tmp/antonia-semantic-authoring.XXXXXX)"

cleanup() {
  case "$TEMP_ROOT" in
    /tmp/antonia-semantic-authoring.*) rm -rf -- "$TEMP_ROOT" ;;
  esac
}
trap cleanup EXIT

for skill in antonia-ontologist antonia-ontop-mapping antonia-onto-steward; do
  test -f "$ROOT/toolbox/.agents/skills/$skill/SKILL.md"
  grep -Fqx "name: $skill" "$ROOT/toolbox/.agents/skills/$skill/SKILL.md"
  grep -Fqx "skill=skills/$skill" "$ROOT/toolbox/.agents/.antonia-managed"
done

test -f "$ROOT/toolbox/.agents/skills/antonia-ontologist/assets/antonia_ontology_candidates.yaml"
test -f "$ROOT/toolbox/.agents/skills/antonia-ontologist/scripts/normalize_document.py"
grep -Fq 'ONTOGPT_ALLOW_EXTERNAL_LLM=0' "$ROOT/toolbox/templates/config/config.env"
grep -Fq 'DB_SAMPLE_TO_LLM=0' "$ROOT/toolbox/templates/config/config.env"
grep -Fq 'validate_shacl.py' "$ROOT/toolbox/report.sh"

printf 'A domain statement.\n' > "$TEMP_ROOT/source.md"
python3 "$ROOT/toolbox/.agents/skills/antonia-ontologist/scripts/normalize_document.py" \
  "$TEMP_ROOT/source.md" "$TEMP_ROOT/normalized.txt"
grep -Fqx 'A domain statement.' "$TEMP_ROOT/normalized.txt"

printf 'jdbc.url=jdbc:postgresql://localhost/example\n' > "$TEMP_ROOT/source.properties"
if python3 "$ROOT/toolbox/sample_database.py" \
    --properties "$TEMP_ROOT/source.properties" --tables '' --limit 20 \
    --output "$TEMP_ROOT/sample.json" > "$TEMP_ROOT/sample.log" 2>&1; then
  echo "Error: database sampler accepted an empty allowlist" >&2
  exit 1
fi
grep -Fq 'no tables authorized for sampling' "$TEMP_ROOT/sample.log"

printf 'verified payload\n' > "$TEMP_ROOT/source.bin"
SOURCE_SHA="$(shasum -a 256 "$TEMP_ROOT/source.bin" | awk '{print $1}')"
(
  source "$ROOT/toolbox/install_semantic_tools.sh"
  download_verified "file://$TEMP_ROOT/source.bin" "$TEMP_ROOT/copy.bin" "$SOURCE_SHA"
  cmp "$TEMP_ROOT/source.bin" "$TEMP_ROOT/copy.bin"
  download_verified "file://$TEMP_ROOT/source.bin" "$TEMP_ROOT/copy.bin" "$SOURCE_SHA"
)
if (
  source "$ROOT/toolbox/install_semantic_tools.sh"
  download_verified "file://$TEMP_ROOT/source.bin" "$TEMP_ROOT/rejected.bin" \
    '0000000000000000000000000000000000000000000000000000000000000000'
) > "$TEMP_ROOT/checksum.log" 2>&1; then
  echo "Error: semantic installer accepted an invalid checksum" >&2
  exit 1
fi
grep -Fq 'checksum mismatch' "$TEMP_ROOT/checksum.log"

HOST_ROOT="$TEMP_ROOT/host"
mkdir -p "$HOST_ROOT/config" "$HOST_ROOT/.tools/bin" "$HOST_ROOT/tmp"
cp -R "$ROOT/toolbox" "$HOST_ROOT/toolbox"
cp "$ROOT/toolbox/templates/config/config.env" "$HOST_ROOT/config/config.env"
sed -i.bak 's|^ONTOGPT_MODEL=$|ONTOGPT_MODEL=openai/test-model|' "$HOST_ROOT/config/config.env"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$HOST_ROOT/.tools/bin/robot"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$HOST_ROOT/.tools/bin/java"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'output=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  if [ "$1" = "--output" ]; then shift; output="$1"; fi' \
  '  shift' \
  'done' \
  'test -n "$output"' \
  'printf "extracted_object: {}\n" > "$output"' \
  > "$HOST_ROOT/.tools/bin/ontogpt"
chmod +x "$HOST_ROOT/.tools/bin/robot" "$HOST_ROOT/.tools/bin/java" \
  "$HOST_ROOT/.tools/bin/ontogpt"
printf 'source text\n' > "$HOST_ROOT/tmp/source.txt"

if "$HOST_ROOT/toolbox/run_ontogpt.sh" \
    "$HOST_ROOT/tmp/source.txt" "$HOST_ROOT/tmp/result.yaml" \
    > "$TEMP_ROOT/consent.log" 2>&1; then
  echo "Error: external OntoGPT call bypassed consent" >&2
  exit 1
fi
grep -Fq 'external LLM processing is not authorized' "$TEMP_ROOT/consent.log"

sed -i.bak 's|^ONTOGPT_ALLOW_EXTERNAL_LLM=0$|ONTOGPT_ALLOW_EXTERNAL_LLM=1|' \
  "$HOST_ROOT/config/config.env"
if [ -x "$ROOT/.tools/semantic/bin/python" ]; then
  mkdir -p "$HOST_ROOT/.tools/semantic/bin"
  printf '%s\n' '#!/usr/bin/env bash' \
    "exec \"$ROOT/.tools/semantic/bin/python\" \"\$@\"" \
    > "$HOST_ROOT/.tools/semantic/bin/python"
  chmod +x "$HOST_ROOT/.tools/semantic/bin/python"
  "$HOST_ROOT/toolbox/run_ontogpt.sh" \
    "$HOST_ROOT/tmp/source.txt" "$HOST_ROOT/tmp/result.yaml"
  test -f "$HOST_ROOT/tmp/result.yaml"
fi

if "$HOST_ROOT/toolbox/run_ontogpt.sh" --contains-db-samples \
    "$HOST_ROOT/tmp/source.txt" "$HOST_ROOT/tmp/sample-result.yaml" \
    > "$TEMP_ROOT/sample-consent.log" 2>&1; then
  echo "Error: database samples bypassed their independent consent" >&2
  exit 1
fi
grep -Fq 'database samples to the LLM is not authorized' \
  "$TEMP_ROOT/sample-consent.log"

if [ -x "$ROOT/.tools/semantic/bin/python" ]; then
  "$ROOT/.tools/semantic/bin/python" - "$TEMP_ROOT" <<'PY'
import sys
from pathlib import Path

import pymupdf
from docx import Document

root = Path(sys.argv[1])
document = Document()
document.add_paragraph("DOCX ontology source")
document.save(root / "source.docx")
pdf = pymupdf.open()
page = pdf.new_page()
page.insert_text((72, 72), "PDF ontology source")
pdf.save(root / "source.pdf")
PY
  "$ROOT/.tools/semantic/bin/python" \
    "$ROOT/toolbox/.agents/skills/antonia-ontologist/scripts/normalize_document.py" \
    "$TEMP_ROOT/source.docx" "$TEMP_ROOT/source-docx.txt"
  "$ROOT/.tools/semantic/bin/python" \
    "$ROOT/toolbox/.agents/skills/antonia-ontologist/scripts/normalize_document.py" \
    "$TEMP_ROOT/source.pdf" "$TEMP_ROOT/source-pdf.txt"
  grep -Fq 'DOCX ontology source' "$TEMP_ROOT/source-docx.txt"
  grep -Fq 'PDF ontology source' "$TEMP_ROOT/source-pdf.txt"

  printf 'invalid: true\n' > "$TEMP_ROOT/invalid-extraction.yaml"
  if "$ROOT/.tools/semantic/bin/python" "$ROOT/toolbox/validate_ontogpt_output.py" \
      "$TEMP_ROOT/invalid-extraction.yaml" > "$TEMP_ROOT/extraction.log" 2>&1; then
    echo "Error: malformed OntoGPT output passed validation" >&2
    exit 1
  fi
  grep -Fq 'missing extracted_object' "$TEMP_ROOT/extraction.log"

  "$ROOT/.tools/semantic/bin/python" - "$ROOT/toolbox/sample_database.py" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("sample_database", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.parse_jdbc_url("jdbc:postgresql://localhost:5432/demo")[0] == "postgresql"
assert module.parse_jdbc_url("jdbc:mysql://localhost:3306/demo")[0] == "mysql"
assert module.split_table("public.customer") == ("public", "customer")
try:
    module.split_table("public.customer;drop")
except ValueError:
    pass
else:
    raise AssertionError("unsafe identifier accepted")
PY

  "$ROOT/.tools/semantic/bin/python" "$ROOT/toolbox/validate_shacl.py" \
    --data "$ROOT/tests/data/shacl/conforming.ttl" \
    --shapes-dir "$ROOT/tests/data/shacl/shapes" \
    --report-rdf "$TEMP_ROOT/conforming-report.ttl" \
    --report-text "$TEMP_ROOT/conforming-report.txt" \
    --fail-on VIOLATION > "$TEMP_ROOT/shacl-conforming.log" 2>&1
  grep -Fq 'Conforms: True' "$TEMP_ROOT/shacl-conforming.log"
  echo "SHACL conforming fixture: passed"

  if "$ROOT/.tools/semantic/bin/python" "$ROOT/toolbox/validate_shacl.py" \
      --data "$ROOT/tests/data/shacl/nonconforming.ttl" \
      --shapes-dir "$ROOT/tests/data/shacl/shapes" \
      --report-rdf "$TEMP_ROOT/nonconforming-report.ttl" \
      --report-text "$TEMP_ROOT/nonconforming-report.txt" \
      --fail-on VIOLATION > "$TEMP_ROOT/shacl-nonconforming.log" 2>&1; then
    echo "Error: SHACL violation did not fail validation" >&2
    exit 1
  fi
  grep -Fq 'Conforms: False' "$TEMP_ROOT/nonconforming-report.txt"
  grep -Fq 'Conforms: False' "$TEMP_ROOT/shacl-nonconforming.log"
  echo "SHACL violation rejection: passed"

  REPORT_ROOT="$TEMP_ROOT/report-host"
  mkdir -p "$REPORT_ROOT/config" "$REPORT_ROOT/.tools/bin" \
    "$REPORT_ROOT/.tools/semantic/bin" "$REPORT_ROOT/tmp" \
    "$REPORT_ROOT/src/shapes/shacl"
  cp -R "$ROOT/toolbox" "$REPORT_ROOT/toolbox"
  cp "$ROOT/toolbox/templates/config/config.env" "$REPORT_ROOT/config/config.env"
  cp "$ROOT/tests/data/shacl/shapes/class-label.ttl" \
    "$REPORT_ROOT/src/shapes/shacl/class-label.ttl"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$REPORT_ROOT/.tools/bin/java"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'output=""' \
    'while [ "$#" -gt 0 ]; do' \
    '  if [ "$1" = "--output" ]; then shift; output="$1"; fi' \
    '  shift' \
    'done' \
    'if [ -n "$output" ]; then mkdir -p "$(dirname "$output")"; : > "$output"; fi' \
    > "$REPORT_ROOT/.tools/bin/robot"
  printf '%s\n' '#!/usr/bin/env bash' \
    "exec \"$ROOT/.tools/semantic/bin/python\" \"\$@\"" \
    > "$REPORT_ROOT/.tools/semantic/bin/python"
  chmod +x "$REPORT_ROOT/.tools/bin/java" "$REPORT_ROOT/.tools/bin/robot" \
    "$REPORT_ROOT/.tools/semantic/bin/python"

  "$ROOT/.tools/semantic/bin/python" - \
    "$ROOT/tests/data/shacl/conforming.ttl" \
    "$REPORT_ROOT/tmp/classified.rdf" <<'PY'
import sys
from rdflib import Graph

Graph().parse(sys.argv[1], format="turtle").serialize(
    destination=sys.argv[2], format="xml"
)
PY
  "$REPORT_ROOT/toolbox/report.sh" > "$TEMP_ROOT/report-conforming.log"
  grep -Fq 'QC completed successfully' "$TEMP_ROOT/report-conforming.log"

  "$ROOT/.tools/semantic/bin/python" - \
    "$ROOT/tests/data/shacl/nonconforming.ttl" \
    "$REPORT_ROOT/tmp/classified.rdf" <<'PY'
import sys
from rdflib import Graph

Graph().parse(sys.argv[1], format="turtle").serialize(
    destination=sys.argv[2], format="xml"
)
PY
  if "$REPORT_ROOT/toolbox/report.sh" > "$TEMP_ROOT/report-nonconforming.log" 2>&1; then
    echo "Error: make report path accepted a SHACL violation" >&2
    exit 1
  fi
  grep -Fq 'SHACL validation failed' "$TEMP_ROOT/report-nonconforming.log"
else
  echo "semantic authoring test: real pySHACL integration skipped (toolchain not installed)"
fi

echo "semantic authoring test: passed"
