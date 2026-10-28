#!/usr/bin/env bash
# Loop 80 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop80/smoke80.sh
# Needs python3.10+ (the ring), the toolchains the ring and the scaffold stage build with (Docker, dotnet, a JDK, cargo,
# node, Swift) and shellcheck; about 12 to 16 minutes on a quiet host (check `uptime` first; the publish gate runs inside
# step 7 and fails when anything in the repository changes while it runs, so write no file in the repo meanwhile).
# What the loop delivered: a seal or mac ring row that the reference refuses is named by the loader, not a traceback
# (AZ-3369 AC-1 to AC-4) and a passed stage is stamped although only the autodev state file is dirty (AC-5). Step 7 is
# `scripts/loop-tests.sh` against stamps at 692edcc, the commit of loop 79's total run (14 passed, record79.md): it runs
# the stages whose files changed since.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke80-failed-logs"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke80: logs kept in $keep"; fi
  rm -rf "$work"
}
trap cleanup EXIT
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
py3="$(command -v python3.14 || command -v python3)"
mkdir -p "$work/bin" && ln -s "$py3" "$work/bin/python3" && export PATH="$work/bin:$PATH"
if [ "$(uname -s)" = Darwin ]; then PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"; export PACKBIN_CXX_SYSROOT; fi
export PACKBIN_RING_WORK="$work/ring" # fresh driver builds: a kept work dir reuses old C# and C++ binaries
cases=fixtures/frame/ring-cases.txt
n_refusals="$(grep -cE '^(open|verify|refuse-seal|refuse-open|refuse-mac) ' "$cases")"
start="$(git log --format=%h -n 1 --grep='^\[AZ-3369\] Start: ring-names-refused-row')"
base=692edcc

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
[ -n "$start" ] || { echo "no start commit"; code=1; }
git rev-parse --verify "$base^{commit}" > /dev/null || { echo "no commit $base"; code=1; }
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3369 AC-1, AC-2: the self-test (stand-in drivers) passes with the two new cases and no traceback in any case.
code=0
limit 300 bash .github/workflows/ring-frame.test.sh > "$work/selftest.out" 2>&1 < /dev/null || code=1
grep -q '^ring-frame.test: all passed$' "$work/selftest.out" || code=1
for c in seal-refused-by-reference mac-refused-by-reference; do
  grep -q "^PASS $c\$" "$work/selftest.out" || { echo "no PASS $c"; code=1; }
done
[ "$(grep -c '^PASS' "$work/selftest.out")" -eq 34 ] || { echo "not 34 PASS lines"; code=1; }
! grep -q '^FAIL' "$work/selftest.out" || { echo "a FAIL line"; code=1; }
step 2 "self-test passes: a refused seal or mac row is named, no traceback" "$code" "$(grep -c '^PASS' "$work/selftest.out") PASS"

# 3. AZ-3369 AC-3: the real ring, all 8 languages, is unchanged.
code=0
[ "$n_refusals" -eq 43 ] || { echo "refusal rows: $n_refusals, wanted 43"; code=1; }
limit 900 bash .github/workflows/ring-frame.sh > "$work/ring.out" 2> "$work/ring.err" < /dev/null || code=1
grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring.out" || { echo "no 64-pair total"; code=1; }
[ "$(grep -c "^refusals [a-z]*: $n_refusals rows, 0 mismatched$" "$work/ring.out")" -eq 8 ] || { echo "not 8 clean refusal lines of $n_refusals rows"; code=1; }
step 3 "real ring: 64 pairs and 8 x $n_refusals refusals, 0 mismatched" "$code" "$(tail -n 1 "$work/ring.out")"

# 4. AZ-3369 AC-4: not vacuous: the checker of the loop start, in a scratch copy of the tree, fails the two new cases
# with a traceback in the output.
code=0
mkdir -p "$work/repo" && git archive HEAD | tar -x -C "$work/repo"
git show "$start:scripts/frame/ring_frame.py" > "$work/repo/scripts/frame/ring_frame.py" || code=1
rc=0
limit 300 bash "$work/repo/.github/workflows/ring-frame.test.sh" > "$work/mut.out" 2> "$work/mut.err" < /dev/null || rc=$?
[ "$rc" -eq 1 ] || { echo "the old checker exited $rc, wanted 1"; code=1; }
for c in seal-refused-by-reference mac-refused-by-reference; do grep -q "^FAIL $c:" "$work/mut.out" || { echo "no FAIL $c"; code=1; }; done
[ "$(grep -c '^FAIL' "$work/mut.out")" -eq 2 ] || { echo "not exactly 2 FAIL lines"; code=1; }
grep -q '^Traceback ' "$work/mut.out" || { echo "no traceback in the old checker's output"; code=1; }
step 4 "the loop-start checker fails the two new cases" "$code" "$(grep -c '^FAIL' "$work/mut.out") FAIL"

# 5. AZ-3369 AC-5: the loop-tests test passes and fails on the loop-start script (the position file blocked the stamp).
code=0
limit 300 bash scripts/loop-tests.test.sh > "$work/lt-test.out" 2>&1 < /dev/null || code=1
grep -q '^loop-tests.test.sh: all checks passed$' "$work/lt-test.out" || code=1
mkdir -p "$work/old/scripts"
git show "$start:scripts/loop-tests.sh" > "$work/old/scripts/loop-tests.sh" || code=1
cp scripts/loop-tests.test.sh "$work/old/scripts/loop-tests.test.sh"
rc=0
limit 300 bash "$work/old/scripts/loop-tests.test.sh" > "$work/lt-old.out" 2>&1 < /dev/null || rc=$?
[ "$rc" -ne 0 ] || { echo "the loop-start script passed the new case"; code=1; }
grep -q '^FAIL: execution: the autodev position file blocked the stamp$' "$work/lt-old.out" || { echo "the new case is not the failing one"; code=1; }
step 5 "a position file alone does not block a stamp; the loop-start script fails that case" "$code"

# 6. Wiring: the job layout and the ring wiring tests.
code=0
for t in .github/workflows/publish-jobs.test.sh .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-lib.test.sh; do
  limit 600 bash "$t" > "$work/$(basename "$t").out" 2>&1 < /dev/null || { echo "$t failed"; code=1; }
done
step 6 "job layout, ring wiring and ring-lib tests pass" "$code"

# 7. The stages whose files changed since loop 79's total run: the plan names exactly scaffold, ring and publish-gate
# (the gate reads ring-* scripts), the other 11 are skipped as unchanged since $base, and the three pass.
code=0
stamps="$work/stamps"
mkdir -p "$stamps"
for s in go typescript csharp python rust java cpp swift scaffold cpp-embedded-arm rust-embedded ring ac10 publish-gate; do
  git rev-parse "$base" > "$stamps/$s"
done
LOOP_TESTS_STAMPS="$stamps" scripts/loop-tests.sh --plan > "$work/plan.out" 2>&1 < /dev/null || code=1
[ "$(grep -E '^PLAN [a-z0-9-]+ RUN' "$work/plan.out" | awk '{print $2}' | paste -sd ' ' -)" = "scaffold ring publish-gate" ] || { echo "the plan runs other stages:"; cat "$work/plan.out"; code=1; }
[ "$(grep -c "^PLAN [a-z0-9-]* SKIP (unchanged since $base)$" "$work/plan.out")" -eq 11 ] || { echo "not 11 stages skipped as unchanged"; code=1; }
lt_log="${SMOKE80_LT_LOG:-$work/lt.out}"
limit 3000 env LOOP_TESTS_STAMPS="$stamps" scripts/loop-tests.sh > "$lt_log" 2>&1 < /dev/null || code=1
grep -q '^RESULT 3 passed, [0-9]* skipped as unchanged, 0 failed' "$lt_log" || { echo "no RESULT line with 3 passed, 0 failed"; code=1; }
for s in scaffold ring publish-gate; do grep -q "^STAGE $s: PASS" "$lt_log" || { echo "stage $s did not pass"; code=1; }; done
cp "$lt_log" "$work/lt.out" 2> /dev/null || true
step 7 "loop-tests: scaffold, ring and publish-gate pass; 11 stages unchanged since $base" "$code" "$(grep '^RESULT' "$lt_log" | tail -n 1)"

# 8. Lint and size: shellcheck on the changed scripts (the two SC2221/SC2222 warnings of loop-tests.sh line 43 are at the
# loop start too), Python compiles, no touched source file went over 500 lines.
code=0
if command -v shellcheck > /dev/null; then
  shellcheck -S warning .github/workflows/ring-frame.test.sh scripts/loop-tests.test.sh || code=1
  now="$(shellcheck -S warning scripts/loop-tests.sh 2> /dev/null | grep -c '^In scripts/loop-tests.sh line')"
  was="$(git show "$start:scripts/loop-tests.sh" | shellcheck -S warning - 2> /dev/null | grep -c '^In - line')"
  [ "$now" -le "$was" ] || { echo "loop-tests.sh has $now shellcheck findings, the loop start $was"; code=1; }
else
  echo "shellcheck not installed"; code=1
fi
python3 -m py_compile scripts/frame/ring_frame.py || code=1
while IFS= read -r f; do
  [ -f "$f" ] || continue
  now="$(wc -l < "$f")"
  was="$(git show "$start:$f" 2> /dev/null | wc -l)" || was=0
  if [ "$now" -gt 500 ] && [ "$was" -le 500 ]; then echo "$f grew from $was to $now lines"; code=1; fi
done < <(git diff --name-only "$start"..HEAD -- . ':(exclude)_docs' ':(exclude)fixtures')
step 8 "shellcheck no worse, Python compiles, no touched source file over 500 lines" "$code"

echo "smoke80: $fails failed"
[ "$fails" -eq 0 ]
