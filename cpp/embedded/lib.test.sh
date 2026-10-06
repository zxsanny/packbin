#!/usr/bin/env bash
# Self-test of the embedded harness (AZ-2099). Runs the real run.sh, lib.sh and report-row.sh from a
# temp tree against fake targets and checks the report rows, the logs and the stage exit code.
# It needs GNU date (lib.sh times a target with date +%s%N), so it runs on the Linux scaffold job.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

case "$(date +%s%N)" in
  *[!0-9]*)
    echo "lib.test.sh needs GNU date: lib.sh uses date +%s%N" >&2
    exit 2
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
scenario_failed=0
stage_rc=0
tree=""

# A temp SRC_ROOT with the real harness files; the scenario writes the fake arm.sh.
new_tree() {
  tree="$tmp/$1"
  mkdir -p "$tree/cpp/embedded" "$tree/.github/workflows"
  cp "$here/run.sh" "$here/lib.sh" "$tree/cpp/embedded/"
  cp "$repo/.github/workflows/report-row.sh" "$tree/.github/workflows/"
}

# Runs `run.sh <stage>` in $tree as a separate process and keeps its output and exit code.
run_stage() {
  stage_rc=0
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" bash "$tree/cpp/embedded/run.sh" "$1" \
    > "$tree/stage.out" 2>&1 || stage_rc=$?
}

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "PASS $label"
  else
    echo "FAIL $label" >&2
    failures=$((failures + 1))
    scenario_failed=1
  fi
}

# After a scenario with a failed check: what the stage printed and what the report holds.
show_evidence() {
  if [ "$scenario_failed" -ne 0 ]; then
    sed 's/^/  stage: /' "$tree/stage.out" >&2
    sed 's/^/  report: /' "$tree/results/report.csv" >&2
    scenario_failed=0
  fi
}

# The last report row of target $1 matches the extended regex $2.
row_matches() {
  awk -F, -v id="$1" '$1 == id { row = $0 } END { print row }' "$tree/results/report.csv" | grep -Eq "$2"
}

rows() {
  [ "$(($(wc -l < "$tree/results/report.csv") - 1))" -eq "$1" ]
}

log_lacks() {
  ! grep -q "$2" "$tree/results/embedded/$1.log"
}

log_has() {
  grep -q "$2" "$tree/results/embedded/$1.log"
}

rc_is() {
  [ "$stage_rc" -eq "$1" ]
}

stage_says() {
  grep -q "$1" "$tree/stage.out"
}

ac1_unchecked_failure_fails_the_target() {
  new_tree ac1
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
helper_copy() { cp "$out/does-not-exist" "$out/copy"; note "after cp"; }
target_m0plus() { false; note "after false"; }
target_m3() { helper_copy; }
target_m4f() { false | cat; note "after pipe"; }
target_s390x() { note "ran after the failures"; }
EOF
  run_stage arm
  check "AC-1 false: row FAIL with exit status and log path" \
    row_matches cpp-m0plus '^cpp-m0plus,.*,FAIL,exit 1 \(log: test-results/embedded/cpp-m0plus\.log\)$'
  check "AC-1 false: the command after it did not run" log_lacks cpp-m0plus "after false"
  check "AC-1 failing cp in a helper: row FAIL" \
    row_matches cpp-m3-qemu '^cpp-m3-qemu,.*,FAIL,exit 1 \(log: test-results/embedded/cpp-m3-qemu\.log\)$'
  check "AC-1 failing cp in a helper: the command after it did not run" log_lacks cpp-m3-qemu "after cp"
  check "AC-1 failing pipeline (pipefail): row FAIL" row_matches cpp-m4f ',FAIL,exit 1 \(log:'
  check "AC-1 failing pipeline (pipefail): the command after it did not run" log_lacks cpp-m4f "after pipe"
  check "F3 false: the log names the failed command and its status" \
    log_has cpp-m0plus "target command failed: false (exit 1"
  check "F3 failing cp in a helper: the log names the cp" \
    log_has cpp-m3-qemu "target command failed: cp .*does-not-exist.* (exit 1"
  check "F3 failing pipeline: the log shows the status of every member" \
    log_has cpp-m4f "(exit 1, pipe 1 0)"
  check "AC-1 the stage exit code is 1" rc_is 1
  check "AC-4 the target after the failed ones still ran and passed" \
    row_matches cpp-s390x ',PASS,ran after the failures; $'
  check "AC-4 one row per target" rows 4
  check "AC-4 the stage reports 3 failed targets" stage_says "embedded stage arm: 3 target(s) failed"
  show_evidence
}

ac2_explicit_checks_continue() {
  new_tree ac2
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { fail "budget A"; note "between"; fail "budget B"; note "after"; }
target_m3() { ( fail "from a subshell" ); note "after the subshell"; }
target_m4f() { note "before exit"; exit 3; }
target_s390x() { note "ok"; }
EOF
  run_stage arm
  check "AC-2 both reasons in one FAIL row, later commands ran" \
    row_matches cpp-m0plus \
    ',FAIL,FAIL budget A; between; FAIL budget B; after; \(log: test-results/embedded/cpp-m0plus\.log\)$'
  check "AC-2 the command after the checks ran" log_has cpp-m0plus "NOTE after"
  check "F3 explicit fail checks leave no failed-command line" log_lacks cpp-m0plus "target command failed"
  check "AC-2 a fail inside a subshell still fails the target" \
    row_matches cpp-m3-qemu ',FAIL,FAIL from a subshell; after the subshell; \(log:'
  check "AC-1 an exit status is shown after the notes" \
    row_matches cpp-m4f ',FAIL,before exit; exit 3 \(log:'
  check "AC-2 the stage exit code is 1" rc_is 1
  show_evidence
}

ac3_passing_target_passes() {
  new_tree ac3
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { note "FAILURES 0"; if false; then :; fi; false || true; [ 1 -eq 2 ] || true; ! false; }
target_m3() { note "ok"; }
target_m4f() { note "ok"; }
target_s390x() { note "ok"; }
EOF
  run_stage arm
  check "F3 failures inside if, || and ! leave no failed-command line" \
    log_lacks cpp-m0plus "target command failed"
  check "AC-3 FAIL in an ordinary note does not fail the target" \
    row_matches cpp-m0plus ',PASS,FAILURES 0; $'
  check "AC-3 all four rows PASS" rows 4
  check "AC-3 the stage exit code is 0" rc_is 0
  check "AC-3 the stage reports 0 failed targets" stage_says "embedded stage arm: 0 target(s) failed"
  show_evidence
}

# Same temp tree and results folder as the AC-2 scenario, whose first target left a failure marker.
earlier_failure_marker_does_not_fail_a_rerun() {
  new_tree ac2
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { note "ok"; }
target_m3() { note "ok"; }
target_m4f() { note "ok"; }
target_s390x() { note "ok"; }
EOF
  run_stage arm
  check "a stale failure marker from the earlier run is cleared" row_matches cpp-m0plus ',PASS,ok; $'
  check "the rerun exits 0" rc_is 0
  show_evidence
}

usage_error_exits_2() {
  new_tree usage
  run_stage bogus
  check "usage error exits 2" rc_is 2
  check "usage error prints the usage line" stage_says "usage:"
  show_evidence
}

errexit_ignoring_call_is_refused() {
  new_tree guard
  local rc=0
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" bash -c '
    source "$1/cpp/embedded/lib.sh"
    target_x() { false; note "after"; }
    run_target x "x" target_x || true
  ' _ "$tree" > "$tree/stage.out" 2>&1 || rc=$?
  stage_rc=$rc
  check "run_target called from an || list is refused (exit 2)" rc_is 2
  check "the refusal says errexit is ignored" stage_says "errexit is ignored"
  show_evidence
}

ac1_unchecked_failure_fails_the_target
ac2_explicit_checks_continue
ac3_passing_target_passes
earlier_failure_marker_does_not_fail_a_rerun
usage_error_exits_2
errexit_ignoring_call_is_refused

if [ "$failures" -ne 0 ]; then
  echo "$failures embedded harness check(s) failed" >&2
  exit 1
fi
echo "embedded harness self-test passed"
