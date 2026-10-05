#!/usr/bin/env bash
# Shared settings and helpers for the embedded targets. Sourced by run.sh.
set -euo pipefail

root="${SRC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cpp="$root/cpp"
here="$cpp/embedded"
results="${TEST_RESULTS:-$root/test-results}"
out="$results/embedded"
build="$cpp/build/embedded"

# Feature AC-1 flags; every core and test source on every target builds with these.
core_flags=(-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror)
c_flags=(-std=c11 -Os -Wall -Wextra -Werror)
core_srcs=(src/core/values.cpp src/core/pack.cpp src/core/unpack.cpp src/core/session.cpp)

# Budgets from feature AC-5.
flash_budget=8192
stack_budget=512

# VECTOR_TESTS straight from cpp/Makefile, so the runner always builds the host's list.
vector_tests() {
  make --no-print-directory -s -C "$cpp" -f Makefile -f "$here/print-var.mk" print-VECTOR_TESTS
}

# Occurrences of a fixed string in a file (0 when absent; fails when the file is unreadable).
count_fixed() {
  local pattern="$1" file="$2"
  test -r "$file"
  awk -v pat="$pattern" '{ s = $0; while ((i = index(s, pat)) > 0) { n++; s = substr(s, i + length(pat)) } } END { print n + 0 }' "$file"
}

# Lines of compiler output that are warnings.
count_warnings() {
  count_fixed "warning:" "$1"
}

# The value after `KEY ` on the first matching line of a run log.
log_value() {
  local key="$1" file="$2"
  awk -v k="$key" '$1 == k { print $2; found = 1; exit } END { if (!found) print "missing" }' "$file"
}

# Runs one target function in a subshell with errexit, tees its log, writes one report row.
# The function may write a one-line summary (no commas) to "$out/<id>.msg".
run_target() {
  local id="$1" name="$2" fn="$3"
  local log="$out/$id.log" msg="$out/$id.msg" started rc elapsed result message
  mkdir -p "$out"
  : > "$msg"
  CURRENT_TARGET="$id"
  started=$(date +%s%N)
  echo "=== $id: $name ==="
  set +e
  (
    set -euo pipefail
    "$fn"
  ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  # A failed check inside a target function does not always stop it (errexit is not reliable
  # inside functions), so any recorded FAIL note fails the target.
  if [ "$rc" -eq 0 ] && grep -q "FAIL" "$msg"; then
    rc=1
  fi
  elapsed=$(( ($(date +%s%N) - started) / 1000000 ))
  message="$(tr ',\n' '; ' < "$msg")"
  if [ "$rc" -eq 0 ]; then
    result=PASS
  else
    result=FAIL
    message="${message:-exit $rc} (log: test-results/embedded/$id.log)"
  fi
  echo "=== $id: $result $message ==="
  TEST_RESULTS="$results" SRC_ROOT="$root" bash "$root/.github/workflows/report-row.sh" \
    "$id" "$name" "$elapsed" "$result" "$message"
  return "$rc"
}

# Appends to the target summary (run inside a target function).
note() {
  printf '%s; ' "$*" >> "$out/$CURRENT_TARGET.msg"
  echo "NOTE $*"
}

# Fails the target with a reason.
fail() {
  note "FAIL $*"
  return 1
}
