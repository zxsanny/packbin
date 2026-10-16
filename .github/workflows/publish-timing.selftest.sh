#!/usr/bin/env bash
# AZ-2563: the timing lines of publish-gate.test.sh. A group prints its seconds, also when it fails; a group that aborts
# the script is named by the EXIT trap; the gate runs exactly the 14 groups, each through `timed`.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Arrange: a driver that sources the real timing file with three stand-in groups.
cat > "$work/driver.sh" <<DRIVER
set -euo pipefail
here="$here"
failures=0
fail() { echo "FAIL: \$*" >&2; failures=\$((failures + 1)); }
source "\$here/publish-timing.test.sh"
ok_group() { :; }
fail_group() { fail "stand-in"; }
abort_group() { false; }
timed alpha ok_group
timed beta fail_group
echo "failures=\$failures"
timed_total
if [ "\${1:-}" = abort ]; then timed gamma abort_group; echo not-reached; fi
DRIVER

# Act
rc=0
out="$(bash "$work/driver.sh" 2>&1 < /dev/null)" || rc=$?

# Assert: both groups timed, the failing one counted once, the total names 2 checks, exit 0.
[ "$rc" -eq 0 ] || bad "driver exit $rc, expected 0"
printf '%s\n' "$out" | grep -Eq '^publish-gate: alpha took [0-9]+ s$' || bad "alpha has no timing line"
printf '%s\n' "$out" | grep -Eq '^publish-gate: beta took [0-9]+ s$' || bad "a failing group has no timing line"
printf '%s\n' "$out" | grep -qx 'failures=1' || bad "the failing group was not counted exactly once"
printf '%s\n' "$out" | grep -Eq '^publish-gate: total took [0-9]+ s in 2 checks$' || bad "total line missing or wrong"

# Act and assert: on GitHub Actions the timing lines also go out as ONE notice annotation (GitHub keeps 10 per step), and only there
out="$(GITHUB_ACTIONS=true bash "$work/driver.sh" 2>&1 < /dev/null)" || bad "driver failed under GITHUB_ACTIONS"
[ "$(printf '%s\n' "$out" | grep -c '^::notice ')" -eq 1 ] || bad "expected exactly one notice annotation"
printf '%s\n' "$out" | grep -Eq '^::notice title=publish gate timing::publish-gate: alpha took [0-9]+ s%0Apublish-gate: beta took [0-9]+ s%0Apublish-gate: total took [0-9]+ s in 2 checks$' || bad "the notice lacks the lines of both groups and the total"
printf '%s\n' "$out" | grep -q '^publish-gate: alpha took' || bad "the plain timing line is gone under GITHUB_ACTIONS"
env -u GITHUB_ACTIONS bash "$work/driver.sh" 2>&1 < /dev/null | grep -q '::notice' && bad "a notice annotation outside GitHub Actions"
many="$(GITHUB_ACTIONS=true bash -c 'set -euo pipefail; failures=0; here="'"$here"'"; source "$here/publish-timing.test.sh"; g() { :; }; for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do timed "g$n" g; done; timed_total' 2>&1 < /dev/null)"
[ "$(printf '%s\n' "$many" | grep -c '^::notice ')" -eq 1 ] || bad "15 timing lines did not make exactly one notice"
printf '%s\n' "$many" | grep -q 'g14 took [0-9]* s%0Apublish-gate: total took' || bad "the last group is missing from the notice"

# Act: a group that aborts under set -e
rc=0
out="$(bash "$work/driver.sh" abort 2>&1 < /dev/null)" || rc=$?

# Assert
[ "$rc" -ne 0 ] || bad "an aborting group did not fail the run"
printf '%s\n' "$out" | grep -Eq '^publish-gate: gamma took [0-9]+ s \(aborted\)$' || bad "an aborting group is not named"
printf '%s\n' "$out" | grep -q 'not-reached' && bad "the run went on after an aborting group"
out="$(GITHUB_ACTIONS=true bash "$work/driver.sh" abort 2>&1 < /dev/null)" || true
printf '%s\n' "$out" | grep -Eq '^::notice title=publish gate timing::.*publish-gate: gamma took [0-9]+ s \(aborted\)$' || bad "an aborting group has no notice annotation"

# Act and assert: the gate runs the 14 groups, each through timed, and nothing bare
expected="static crates-token registry vcpkg gate go swift manifest npm position workflow pins phases readonly"
got="$(sed -n 's/^timed \([a-z-]*\) [a-z_]*$/\1/p' "$here/publish-gate.test.sh" | tr '\n' ' ' | sed 's/ $//')"
[ "$got" = "$expected" ] || bad "timed groups are [$got], expected [$expected]"
for fn in static_checks crates_token_checks registry_checks vcpkg_checks gate_checks go_checks swift_checks manifest_checks \
  npm_dist_checks position_checks workflow_checks pins_checks phase_checks readonly_checks; do
  n="$(grep -c "^$fn\$" "$here/publish-gate.test.sh" || true)"
  [ "$n" -eq 0 ] || bad "$fn is called bare, outside timed"
done

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish timing self-test passed"
