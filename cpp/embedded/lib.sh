#!/usr/bin/env bash
# Shared settings and helpers for the embedded targets. Sourced by run.sh.
set -euo pipefail

root="${SRC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cpp="$root/cpp"
here="$cpp/embedded"
results="${TEST_RESULTS:-$root/test-results}"
out="$results/embedded"
build="$cpp/build/embedded"
# Downloaded toolchains (arduino-cli, the Arduino ESP32 core, PlatformIO; several GB). Kept outside
# cpp/: `make clean` would delete them from build/, and the package tools (compote, pio pkg pack)
# walk every file under cpp/ before applying their include lists.
cache="${PACKBIN_EMBEDDED_CACHE:-$root/.cache/embedded}"

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

# Targets that did not pass in this run; run.sh exits 1 when it is not 0.
failed=0

# Runs one target function in a child process with errexit on, tees its log, writes one report row
# and counts a failed target in $failed. The function may write a one-line summary (no commas) to
# "$out/<id>.msg".
#
# A target fails when the function exits non-zero (a command nobody checked failed, or a helper
# returned non-zero) or when `fail` was called, which leaves the marker "$out/<id>.failed". The
# summary text plays no part in the decision.
#
# Bash ignores errexit for every command inside a function that an `||`, `&&` or `if` list calls,
# even where that code sets it again, so run_target must be called as a plain command. It returns 0
# whatever the target did: the result is the report row and $failed.
run_target() {
  local id="$1" name="$2" fn="$3"
  local log="$out/$id.log" msg="$out/$id.msg" marker="$out/$id.failed"
  local errexit=off probe started rc elapsed result message
  case $- in *e*) errexit=on ;; esac
  set +e
  ( set -e; false; exit 0 )
  probe=$?
  [ "$errexit" = off ] || set -e
  if [ "$probe" -ne 1 ]; then
    echo "run_target $id: errexit is ignored in this call (called from an ||, && or if list)" >&2
    exit 2
  fi
  mkdir -p "$out"
  : > "$msg"
  rm -f "$marker"
  CURRENT_TARGET="$id"
  started=$(date +%s%N)
  echo "=== $id: $name ==="
  set +e
  (
    set -Eeuo pipefail
    # errexit ends the target without a word; the ERR trap (inherited by functions through -E) names the
    # command first. It does not run in an `||`, `&&` or `if` condition, so explicit checks stay quiet.
    # In a pipeline the command is the last member; the member statuses show which one failed.
    trap 'echo "target command failed: $BASH_COMMAND (exit $?, pipe ${PIPESTATUS[*]})" >&2' ERR
    "$fn"
  ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  [ "$errexit" = off ] || set -e
  elapsed=$(( ($(date +%s%N) - started) / 1000000 ))
  message="$(tr ',\n' '; ' < "$msg")"
  result=PASS
  if [ "$rc" -ne 0 ] || [ -e "$marker" ]; then
    result=FAIL
    [ "$rc" -eq 0 ] || message="${message}exit $rc "
    message="${message}(log: test-results/embedded/$id.log)"
    failed=$((failed + 1))
  fi
  echo "=== $id: $result $message ==="
  TEST_RESULTS="$results" SRC_ROOT="$root" bash "$root/.github/workflows/report-row.sh" \
    "$id" "$name" "$elapsed" "$result" "$message"
}

# Appends to the target summary (run inside a target function).
note() {
  printf '%s; ' "$*" >> "$out/$CURRENT_TARGET.msg"
  echo "NOTE $*"
}

# Records a failed check and returns 0, so the target goes on and reports every violated check. The
# marker file is what fails the target, also when `fail` ran in a subshell. Where going on makes no
# sense (a compile that produced no object), follow it with `return 1`: errexit ends the target.
fail() {
  note "FAIL $*"
  : > "$out/$CURRENT_TARGET.failed"
}
