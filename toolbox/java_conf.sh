#!/usr/bin/env bash
# Generate a Java runtime profile based on the currently available free resources.
# The output is written to conf/java.conf and then consumed by JAVA_TOOL_OPTIONS.
set -euo pipefail

# Resolve ROOT using common.sh logic (supports submodule mode)
source "$(dirname "$0")/common.sh"

CONF_DIR="${CONF_DIR:-$ROOT/config}"
JAVA_CONF="${JAVA_CONF:-$CONF_DIR/java.conf}"
mkdir -p "$CONF_DIR"

available_cpus() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
    return 0
  fi

  if [ -f /proc/cpuinfo ]; then
    grep -c '^processor' /proc/cpuinfo
    return 0
  fi

  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu
    return 0
  fi

  echo 1
}

available_memory_mb() {
  if [ -f /proc/meminfo ]; then
    awk '/MemAvailable/ {print int($2/1024); exit}' /proc/meminfo
    return 0
  fi

  if command -v sysctl >/dev/null 2>&1; then
    echo $(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
    return 0
  fi

  echo 2048
}

cpu_count="$(available_cpus)"
mem_mb="$(available_memory_mb)"

# Keep the JVM conservative to avoid OOM failures on large ontologies.
# Prefer fewer CPUs and a bounded heap, while still allowing explicit override.
if [ "${JAVA_CPU_LIMIT:-}" != "" ]; then
  cpu_count="$JAVA_CPU_LIMIT"
fi
if [ "$cpu_count" -gt 4 ]; then
  cpu_count=4
fi
if [ "$cpu_count" -lt 1 ]; then
  cpu_count=1
fi

if [ "${JAVA_HEAP_LIMIT_MB:-}" != "" ]; then
  heap_mb="$JAVA_HEAP_LIMIT_MB"
else
  heap_mb=$(( mem_mb * 30 / 100 ))
fi
if [ "$heap_mb" -lt 512 ]; then
  heap_mb=512
fi
if [ "$heap_mb" -gt 1024 ]; then
  heap_mb=1024
fi

cat > "$JAVA_CONF" <<EOF
-XX:ActiveProcessorCount=${cpu_count}
-Xms256m
-Xmx${heap_mb}m
EOF

echo "✓ Java profile written to ${JAVA_CONF#$ROOT/}"
echo "  CPUs: ${cpu_count} | free memory: ${mem_mb} MB | Xmx: ${heap_mb}m"
