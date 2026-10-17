#!/usr/bin/env bash
# AZ-2563: the timing lines of publish-gate.test.sh. A group prints its seconds, also when it fails; a group that aborts
# the script is named by the EXIT trap; the gate runs exactly the 16 groups, each through `group` and `timed`; --groups
# (AZ-2600) selects some of them; each read-only check runs in exactly one of the three read-only groups (AZ-2607).
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

# Act and assert: the gate runs the 16 groups, each through `group` (which calls timed), and nothing bare
expected="static crates-token registry vcpkg gate go swift manifest npm position workflow pins phases readonly readonly-gate readonly-full"
got="$(sed -n 's/^group \([a-z-]*\) \([a-z_]*\)$/\1=\2/p' "$here/publish-gate.test.sh" | tr '\n' ' ' | sed 's/ $//')"
expected_fns="static=static_checks crates-token=crates_token_checks registry=registry_checks vcpkg=vcpkg_checks gate=gate_checks go=go_checks swift=swift_checks manifest=manifest_checks npm=npm_dist_checks position=position_checks workflow=workflow_checks pins=pins_checks phases=phase_checks readonly=readonly_checks readonly-gate=ro_gate_checks readonly-full=ro_full_run_check"
[ "$got" = "$expected_fns" ] || bad "grouped checks are [$got], expected [$expected_fns]"
listed="$(sed -n 's/^gate_groups="\(.*\)"$/\1/p' "$here/publish-gate.test.sh")"
[ "$listed" = "$expected" ] || bad "gate_groups is [$listed], expected [$expected]"
[ "$(grep -c ') timed "\$1" "\$2" ;;$' "$here/publish-gate.test.sh")" -eq 1 ] || bad "the group helper does not call timed exactly once"
if grep -q '^timed [a-z-]* [a-z_]*$' "$here/publish-gate.test.sh"; then bad "a group is timed outside the --groups selection"; fi

# Act and assert (AZ-2600): --groups runs only the named groups. The real selection lines of publish-gate.test.sh
# (from gate_groups= to the first group call) run in a driver with a stand-in `timed`, so no real group runs.
sed -n '/^gate_groups=/,/^group static /p' "$here/publish-gate.test.sh" | sed '$d' > "$work/select.sh"
grep -q '^group() {' "$work/select.sh" || bad "the selection lines of publish-gate.test.sh were not found"
for names in "manifest" "manifest,position" "position,manifest"; do
  out="$(bash -c 'set -euo pipefail; timed() { echo "ran $1 $2"; }; names=$1; snip=$2; set -- --groups "$names"; source "$snip"
    group static f_static; group manifest f_manifest; group position f_position; group readonly f_readonly' _ "$names" "$work/select.sh" 2>&1 < /dev/null)" \
    || bad "--groups $names failed: $out"
  expect="$(printf '%s\n' "$names" | tr ',' '\n' | sort | tr '\n' ' ')"
  got="$(printf '%s\n' "$out" | sed -n 's/^ran \([a-z-]*\) .*/\1/p' | sort | tr '\n' ' ')"
  [ "$got" = "$expect" ] || bad "--groups $names ran [$got], expected [$expect]"
done
out="$(bash -c 'set -euo pipefail; timed() { echo "ran $1 $2"; }; snip=$1; set --; source "$snip"; group static f_static; group manifest f_manifest' _ "$work/select.sh" 2>&1 < /dev/null)" \
  || bad "no --groups failed: $out"
[ "$(printf '%s\n' "$out" | grep -c '^ran ')" -eq 2 ] || bad "no --groups did not run every group asked for: $out"
rc=0
out="$(bash "$here/publish-gate.test.sh" --groups manifest,no-such-group 2>&1 < /dev/null)" || rc=$?
[ "$rc" -eq 2 ] || bad "an unknown group exited $rc, expected 2"
printf '%s\n' "$out" | grep -q "unknown group 'no-such-group'" || bad "an unknown group is not named: $out"
printf '%s\n' "$out" | grep -q 'publish-gate: manifest took' && bad "a group ran although another was unknown"
rc=0
bash "$here/publish-gate.test.sh" --groups "" >/dev/null 2>&1 < /dev/null || rc=$?
[ "$rc" -eq 2 ] || bad "an empty group list exited $rc, expected 2"
for fn in static_checks crates_token_checks registry_checks vcpkg_checks gate_checks go_checks swift_checks manifest_checks \
  npm_dist_checks position_checks workflow_checks pins_checks phase_checks readonly_checks ro_gate_checks ro_full_run_check; do
  n="$(grep -c "^$fn\$" "$here/publish-gate.test.sh" || true)"
  [ "$n" -eq 0 ] || bad "$fn is called bare, outside timed"
done

# Act and assert (AZ-2607): a check file that the gate sources sets no EXIT trap of its own that drops the timing trap
# (the vcpkg group did: an abort after it, in the same job, was not named). A trap line there must call timed_abort.
for f in "$here"/publish-*.test.sh; do
  case "$(basename "$f")" in publish-jobs.test.sh | publish-precheck.test.sh | publish-position.test.sh | publish-timing.test.sh) continue ;; esac
  if grep -nE "^[[:space:]]*trap .* EXIT" "$f" | grep -v timed_abort; then
    bad "$(basename "$f") sets an EXIT trap that does not call timed_abort"
  fi
done
sed 's/; if declare -F timed_abort > \/dev\/null; then timed_abort; fi//' "$here/publish-vcpkg.test.sh" > "$work/vcpkg-no-chain.sh"
cmp -s "$here/publish-vcpkg.test.sh" "$work/vcpkg-no-chain.sh" && bad "the trap mutant did not change publish-vcpkg.test.sh"
if grep -nE "^[[:space:]]*trap .* EXIT" "$work/vcpkg-no-chain.sh" | grep -qv timed_abort; then
  echo "trap check rejects: a vcpkg trap without timed_abort"
else
  bad "the trap check accepted a vcpkg trap without timed_abort"
fi

# ro_split <publish-gate.test.sh> <publish-readonly.test.sh>: prints one line per read-only check (a function
# ro_*_check or ro_*_checks of the second file) that does not run exactly once, as a line of readonly_checks or as the
# function of a `group` line of the first file; exit 0 when there is none.
ro_split() {
  local gate="$1" ro="$2" fn body n bad_lines=""
  body="$(awk '/^readonly_checks\(\) \{$/ { on = 1; next } on && /^\}$/ { exit } on { print }' "$ro")"
  for fn in $(sed -n 's/^\(ro_[a-z_]*_checks*\)() {$/\1/p' "$ro"); do
    n=$(( $(grep -cx "  $fn" <<< "$body" || true) + $(grep -cx "group [a-z-]* $fn" "$gate" || true) ))
    [ "$n" -eq 1 ] || bad_lines="$bad_lines$fn runs in $n groups, not 1"$'\n'
  done
  [ -n "$(sed -n 's/^\(ro_[a-z_]*_checks*\)() {$/\1/p' "$ro")" ] || bad_lines="no read-only checks found in $ro"$'\n'
  printf '%s' "$bad_lines"
  [ -z "$bad_lines" ]
}

# Act and assert (AZ-2607): the real files, then one mutant per rule.
if out="$(ro_split "$here/publish-gate.test.sh" "$here/publish-readonly.test.sh")"; then
  echo "read-only checks: each in exactly one group"
else
  bad "read-only check split: $out"
fi
ro_mutant() {
  local label="$1" file="$2" script="$3" gate="$here/publish-gate.test.sh" ro="$here/publish-readonly.test.sh" copy
  copy="$work/mutant-$(basename "$file")"
  sed "$script" "$here/$file" > "$copy"
  if cmp -s "$here/$file" "$copy"; then bad "the mutant did not change $file: $label"; return; fi
  case "$file" in publish-gate.test.sh) gate="$copy" ;; *) ro="$copy" ;; esac
  if out="$(ro_split "$gate" "$ro")"; then bad "the read-only split check accepted a mutant: $label"; else echo "read-only split rejects: $label ($out)"; fi
}
ro_mutant "a check dropped from readonly_checks" publish-readonly.test.sh '/^  ro_probe_checks$/d'
ro_mutant "a check in readonly_checks and in its own group" publish-readonly.test.sh 's/^  ro_host_path_check$/  ro_host_path_check\
  ro_gate_checks/'
ro_mutant "a read-only group line removed" publish-gate.test.sh '/^group readonly-full ro_full_run_check$/d'
ro_mutant "a new read-only check in no group" publish-readonly.test.sh 's/^readonly_checks() {$/ro_extra_check() {\
  :\
}\
readonly_checks() {/'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish timing self-test passed"
