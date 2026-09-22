#!/usr/bin/env bash
set -euo pipefail

root="${SRC_ROOT:-.}"
results="${TEST_RESULTS:-$root/test-results}"
id="${1:?id}"
name="${2:?name}"
elapsed_ms="${3:?elapsed_ms}"
result="${4:?result}"
message="${5:-}"
mkdir -p "$results"
report="$results/report.csv"
header="Test ID,Test Name,Execution Time (ms),Result,Error Message"

if [ "${PACKBIN_REPORT_LOCKED:-}" != 1 ] && command -v flock >/dev/null 2>&1; then
  exec flock "$results/report.lock" env PACKBIN_REPORT_LOCKED=1 "$0" "$@"
fi

if [ ! -f "$report" ] || ! head -n 1 "$report" | grep -qx "$header"; then
  printf '%s\n' "$header" > "$report"
fi
printf '%s,%s,%s,%s,%s\n' "$id" "$name" "$elapsed_ms" "$result" "$message" >> "$report"
