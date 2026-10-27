#!/usr/bin/env bash
# AZ-2563: the timing lines of publish-gate.test.sh. A group prints its seconds, also when it fails; a group that aborts
# the script is named by the EXIT trap; the gate runs exactly the 19 groups, each through `group` and `timed`; --groups
# (AZ-2600) selects some of them; each read-only check runs in exactly one of the five read-only groups (AZ-2607,
# AZ-2625) and each phase check in exactly one of the two phase groups (AZ-2625).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
# bad_in <captured text> <message>: bad, then the text the check matched against (stderr), so a failure shows its evidence.
bad_in() {
  local text="$1"
  shift
  bad "$@"
  printf '  captured output:\n  | %s\n' "${text//$'\n'/$'\n  | '}" >&2
}

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
grep -Eq '^publish-gate: alpha took [0-9]+ s$' <<< "$out" || bad_in "$out" "alpha has no timing line"
grep -Eq '^publish-gate: beta took [0-9]+ s$' <<< "$out" || bad_in "$out" "a failing group has no timing line"
grep -qx 'failures=1' <<< "$out" || bad_in "$out" "the failing group was not counted exactly once"
grep -Eq '^publish-gate: total took [0-9]+ s in 2 checks$' <<< "$out" || bad_in "$out" "total line missing or wrong"

# Act and assert: on GitHub Actions the timing lines also go out as ONE notice annotation (GitHub keeps 10 per step), and only there
out="$(GITHUB_ACTIONS=true bash "$work/driver.sh" 2>&1 < /dev/null)" || bad "driver failed under GITHUB_ACTIONS"
[ "$(grep -c '^::notice ' <<< "$out")" -eq 1 ] || bad_in "$out" "expected exactly one notice annotation"
grep -Eq '^::notice title=publish gate timing::publish-gate: alpha took [0-9]+ s%0Apublish-gate: beta took [0-9]+ s%0Apublish-gate: total took [0-9]+ s in 2 checks$' <<< "$out" || bad_in "$out" "the notice lacks the lines of both groups and the total"
grep -q '^publish-gate: alpha took' <<< "$out" || bad_in "$out" "the plain timing line is gone under GITHUB_ACTIONS"
out="$(env -u GITHUB_ACTIONS bash "$work/driver.sh" 2>&1 < /dev/null)" || bad "driver failed outside GitHub Actions"
grep -q '::notice' <<< "$out" && bad_in "$out" "a notice annotation outside GitHub Actions"
many="$(GITHUB_ACTIONS=true bash -c 'set -euo pipefail; failures=0; here="'"$here"'"; source "$here/publish-timing.test.sh"; g() { :; }; for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do timed "g$n" g; done; timed_total' 2>&1 < /dev/null)"
[ "$(grep -c '^::notice ' <<< "$many")" -eq 1 ] || bad_in "$many" "15 timing lines did not make exactly one notice"
grep -q 'g14 took [0-9]* s%0Apublish-gate: total took' <<< "$many" || bad_in "$many" "the last group is missing from the notice"

# Act: a group that aborts under set -e
rc=0
out="$(bash "$work/driver.sh" abort 2>&1 < /dev/null)" || rc=$?

# Assert
[ "$rc" -ne 0 ] || bad "an aborting group did not fail the run"
grep -Eq '^publish-gate: gamma took [0-9]+ s \(aborted\)$' <<< "$out" || bad_in "$out" "an aborting group is not named"
grep -q 'not-reached' <<< "$out" && bad_in "$out" "the run went on after an aborting group"
out="$(GITHUB_ACTIONS=true bash "$work/driver.sh" abort 2>&1 < /dev/null)" || true
grep -Eq '^::notice title=publish gate timing::.*publish-gate: gamma took [0-9]+ s \(aborted\)$' <<< "$out" || bad_in "$out" "an aborting group has no notice annotation"

# Act and assert: the gate runs the 19 groups, each through `group` (which calls timed), and nothing bare
expected="static crates-token registry vcpkg gate go swift manifest npm position workflow pins phases phases-rerun readonly readonly-gate-good readonly-gate-bad readonly-gate-nojava readonly-full"
got="$(sed -n 's/^group \([a-z-]*\) \([a-z_]*\)$/\1=\2/p' "$here/publish-gate.test.sh" | tr '\n' ' ' | sed 's/ $//')"
expected_fns="static=static_checks crates-token=crates_token_checks registry=registry_checks vcpkg=vcpkg_checks gate=gate_checks go=go_checks swift=swift_checks manifest=manifest_checks npm=npm_dist_checks position=position_checks workflow=workflow_checks pins=pins_checks phases=phase_checks phases-rerun=phase_rerun_checks readonly=readonly_checks readonly-gate-good=ro_gate_good_check readonly-gate-bad=ro_gate_bad_check readonly-gate-nojava=ro_gate_nojava_check readonly-full=ro_full_run_check"
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
[ "$(grep -c '^ran ' <<< "$out")" -eq 2 ] || bad_in "$out" "no --groups did not run every group asked for"
rc=0
out="$(bash "$here/publish-gate.test.sh" --groups manifest,no-such-group 2>&1 < /dev/null)" || rc=$?
[ "$rc" -eq 2 ] || bad "an unknown group exited $rc, expected 2"
grep -q "unknown group 'no-such-group'" <<< "$out" || bad_in "$out" "an unknown group is not named"
grep -q 'publish-gate: manifest took' <<< "$out" && bad_in "$out" "a group ran although another was unknown"
rc=0
bash "$here/publish-gate.test.sh" --groups "" >/dev/null 2>&1 < /dev/null || rc=$?
[ "$rc" -eq 2 ] || bad "an empty group list exited $rc, expected 2"
for fn in static_checks crates_token_checks registry_checks vcpkg_checks gate_checks go_checks swift_checks manifest_checks \
  npm_dist_checks position_checks workflow_checks pins_checks phase_checks phase_rerun_checks readonly_checks ro_gate_good_check ro_gate_bad_check ro_gate_nojava_check ro_full_run_check; do
  n="$(grep -c "^$fn\$" "$here/publish-gate.test.sh" || true)"
  [ "$n" -eq 0 ] || bad "$fn is called bare, outside timed"
done

# Act and assert (AZ-2607): a check file that is sourced into the gate sets no EXIT trap of its own that drops the timing
# trap (the vcpkg group did: an abort after it, in the same job, was not named). A trap line there must call timed_abort.
# The sourced files are the ones some publish script names in a `source "$here/<file>"` line; a standalone script
# (publish-jobs.test.sh, publish-position.test.sh, ...) owns its trap.
# trap_offenders <dir>: one line per sourced publish-*.test.sh of <dir> with an EXIT trap that lacks timed_abort.
trap_offenders() {
  local dir="$1" f name
  for f in "$dir"/publish-*.test.sh; do
    name="$(basename "$f")"
    grep -qF "source \"\$here/$name\"" "$dir"/publish-*.sh || continue
    if grep -nE "^[[:space:]]*trap .* EXIT" "$f" | grep -qv timed_abort; then echo "$name"; fi
  done
}
if out="$(trap_offenders "$here")" && [ -z "$out" ]; then
  echo "EXIT traps of the sourced check files: each calls timed_abort"
else
  bad "sourced check files with an EXIT trap that does not call timed_abort: $out"
fi
mkdir -p "$work/traps"
printf '%s\n' 'source "$here/publish-sourced-bad.test.sh"' > "$work/traps/publish-main.sh"
printf '%s\n' "trap 'rm -rf x' EXIT" > "$work/traps/publish-sourced-bad.test.sh"
printf '%s\n' "trap 'rm -rf x' EXIT" > "$work/traps/publish-standalone.test.sh"
printf '%s\n' "trap 'rm -rf x; timed_abort' EXIT" > "$work/traps/publish-sourced-ok.test.sh"
printf '%s\n' 'source "$here/publish-sourced-ok.test.sh"' >> "$work/traps/publish-main.sh"
[ "$(trap_offenders "$work/traps")" = "publish-sourced-bad.test.sh" ] \
  || bad "the trap rule did not single out the sourced file without timed_abort: [$(trap_offenders "$work/traps")]"
sed 's/; if declare -F timed_abort > \/dev\/null; then timed_abort; fi//' "$here/publish-vcpkg.test.sh" > "$work/vcpkg-no-chain.sh"
cmp -s "$here/publish-vcpkg.test.sh" "$work/vcpkg-no-chain.sh" && bad "the trap mutant did not change publish-vcpkg.test.sh"
mkdir -p "$work/real"
cp "$here"/publish-*.sh "$work/real/"
cp "$work/vcpkg-no-chain.sh" "$work/real/publish-vcpkg.test.sh"
if [ "$(trap_offenders "$work/real")" = "publish-vcpkg.test.sh" ]; then
  echo "trap check rejects: a vcpkg trap without timed_abort"
else
  bad "the trap check did not reject a vcpkg trap without timed_abort: [$(trap_offenders "$work/real")]"
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
  ro_gate_good_check/'
ro_mutant "a read-only group line removed" publish-gate.test.sh '/^group readonly-full ro_full_run_check$/d'
ro_mutant "a scenario group line removed" publish-gate.test.sh '/^group readonly-gate-bad ro_gate_bad_check$/d'
ro_mutant "a new read-only check in no group" publish-readonly.test.sh 's/^readonly_checks() {$/ro_extra_check() {\
  :\
}\
readonly_checks() {/'

# ph_split <publish-gate.test.sh> <phases file> <failures file> <rerun file>: prints one line per phase check (a ph_*
# function of the three files that is not part of the harness) that does not run exactly once, as a line of the body of
# the function of a `group phases*` line of the first file; exit 0 when there is none. The harness functions are the
# ones that build stubs, trees and runs for the checks; a new ph_* function is a check unless it is named there.
ph_harness="ph_write_stub ph_write_spy ph_write_curl_stub ph_setup ph_cleanup ph_bares ph_publish ph_no_refs ph_set_credentials ph_quote"
ph_split() {
  local gate="$1" fn body="" group_fn n bad_lines="" checks
  shift
  for group_fn in $(sed -n 's/^group phases[a-z-]* \([a-z_]*\)$/\1/p' "$gate"); do
    body="$body$(awk -v f="$group_fn" '$0 == f "() {" { on = 1; next } on && /^\}$/ { exit } on { print }' "$@")"$'\n'
  done
  checks="$(sed -n 's/^\(ph_[a-z_]*\)() {$/\1/p' "$@" | grep -vxF -f <(tr ' ' '\n' <<< "$ph_harness") || true)"
  [ -n "$checks" ] || bad_lines="no phase checks found"$'\n'
  for fn in $checks; do
    n="$(grep -cx "  $fn" <<< "$body" || true)"
    [ "$n" -eq 1 ] || bad_lines="$bad_lines$fn runs in $n phase groups, not 1"$'\n'
  done
  printf '%s' "$bad_lines"
  [ -z "$bad_lines" ]
}

# Act and assert (AZ-2625): the real files, then one mutant per rule.
if out="$(ph_split "$here/publish-gate.test.sh" "$here/publish-phases.test.sh" "$here/publish-phases-failures.test.sh" "$here/publish-rerun.test.sh")"; then
  echo "phase checks: each in exactly one group"
else
  bad "phase check split: $out"
fi
ph_mutant() {
  local label="$1" file="$2" script="$3" gate="$here/publish-gate.test.sh" phases="$here/publish-phases.test.sh" copy
  copy="$work/mutant-$(basename "$file")"
  sed "$script" "$here/$file" > "$copy"
  if cmp -s "$here/$file" "$copy"; then bad "the mutant did not change $file: $label"; return; fi
  case "$file" in publish-gate.test.sh) gate="$copy" ;; *) phases="$copy" ;; esac
  if out="$(ph_split "$gate" "$phases" "$here/publish-phases-failures.test.sh" "$here/publish-rerun.test.sh")"; then
    bad "the phase split check accepted a mutant: $label"
  else
    echo "phase split rejects: $label ($out)"
  fi
}
ph_mutant "a check dropped from phase_rerun_checks" publish-phases.test.sh '/^  ph_rerun_checks$/d'
ph_mutant "a check in both phase groups" publish-phases.test.sh 's/^  ph_build_only$/  ph_build_only\
  ph_rerun_checks/'
ph_mutant "a phase group line removed" publish-gate.test.sh '/^group phases-rerun phase_rerun_checks$/d'
ph_mutant "a new phase check in no group" publish-phases.test.sh 's/^phase_checks() {$/ph_extra_check() {\
  :\
}\
phase_checks() {/'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish timing self-test passed"
