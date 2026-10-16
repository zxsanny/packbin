#!/usr/bin/env bash
# Sourced by publish-gate.test.sh. `timed <name> <command...>` runs one check group and prints
# `publish-gate: <name> took N s`; a group that aborts the script (set -e) is reported by the EXIT trap.
# `timed_total` prints the sum line. The group runs as a plain command, so `set -e` inside it is unchanged.
gate_started=$SECONDS
timed_current=""
timed_start=0
timed_count=0

timed_abort() {
  if [ -n "$timed_current" ]; then
    echo "publish-gate: $timed_current took $((SECONDS - timed_start)) s (aborted)" >&2
  fi
}
trap timed_abort EXIT

# On GitHub Actions every timing line is also an annotation: the check-run annotations of a job are readable without a
# token, the job log is not (the speed work of AZ-2582 reads the per-group seconds of a CI run from them).
timed_say() {
  echo "$1"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::notice title=publish gate timing::$1"
  fi
}

timed() {
  timed_current="$1"
  timed_start=$SECONDS
  shift
  "$@"
  timed_say "publish-gate: $timed_current took $((SECONDS - timed_start)) s"
  timed_current=""
  timed_count=$((timed_count + 1))
}

timed_total() {
  timed_say "publish-gate: total took $((SECONDS - gate_started)) s in $timed_count checks"
}

# The position program test runs as a child process; a failure counts like any other group failure.
# shellcheck disable=SC2154  # $here is set by publish-gate.test.sh, which sources this file
position_checks() {
  bash "$here/publish-position.test.sh" || fail "AZ-2238 AC-1 AC-2 publish-position.test.sh failed"
}
