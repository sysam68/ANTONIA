#!/usr/bin/env bash
# Shared progress helpers for make targets.
# Usage:
#   source ./scripts/progress.sh
#   progress_bar 2 5 "reason"
#   progress_step 2 5 "reason"

progress_bar() {
  local current="${1:-0}"
  local total="${2:-1}"
  local label="${3:-step}"
  local width=30
  local percent filled empty

  [ "$total" -gt 0 ] || total=1
  percent=$(( current * 100 / total ))
  filled=$(( current * width / total ))
  empty=$(( width - filled ))

  local fill_str empty_str
  fill_str=$(printf '%*s' "$filled" '' | tr ' ' '#')
  empty_str=$(printf '%*s' "$empty" '' | tr ' ' ' ')

  printf '\r[%s%s] %3d%% %s' "$fill_str" "$empty_str" "$percent" "$label"
}

progress_step() {
  local current="${1:-0}"
  local total="${2:-1}"
  local label="${3:-step}"
  printf '\n▶ [%s/%s] %s\n' "$current" "$total" "$label"
}

progress_done() {
  local current="${1:-0}"
  local total="${2:-1}"
  local label="${3:-step}"
  printf '✓ [%s/%s] %s\n' "$current" "$total" "$label"
}
