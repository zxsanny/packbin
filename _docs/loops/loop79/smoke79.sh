#!/usr/bin/env bash
# Loop 79 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop79/smoke79.sh
# Needs Docker (the Go driver, rust:1.98), dotnet 10, a JDK 17+, cargo, python3.10+, node 22 and Swift on PATH; about 3 to 5
# minutes on a quiet host (check `uptime` first). Step 11 of the loop (scripts/loop-tests.sh --all) is the total run; this
# script re-checks what the loop delivered with the real drivers and the rust:1.98 image: one number range rule in the 8
# frame drivers and the ring loader (AZ-3356) and warning-free test builds of the 9 Rust feature sets (AZ-3357).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke79-failed-logs"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke79: logs kept in $keep"; fi
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
start="$(git log --format=%h -n 1 --grep='^Start: ring-and-test-build-fixes')"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3356 AC-4, AC-7: the self-test (stand-in drivers) passes, with the loader and "... and N more" cases.
code=0
limit 300 bash .github/workflows/ring-frame.test.sh > "$work/selftest.out" 2>&1 < /dev/null || code=1
grep -q '^ring-frame.test: all passed$' "$work/selftest.out" || code=1
for c in refusals-7 pair-6 refusals-5 row-dir-256 row-out-len-65536; do
  grep -q "^PASS $c\$" "$work/selftest.out" || { echo "no PASS $c"; code=1; }
done
step 2 "self-test passes: loader refuses out-of-range rows, no hidden mismatch" "$code" "$(grep -c '^PASS' "$work/selftest.out") PASS"

# 3. AZ-3356 AC-5: the real ring, all 8 languages, with the 6 rows at the top of the ranges.
code=0
[ "$n_refusals" -eq 43 ] || { echo "refusal rows: $n_refusals, wanted 43"; code=1; }
for r in R.seal.dir255 R.seal.tag255 R.seal.kind255 R.seal.epochffffffff R.mac.n255 E1.out65535; do
  grep -q " $r " "$cases" || { echo "no row $r"; code=1; }
done
limit 900 bash .github/workflows/ring-frame.sh > "$work/ring.out" 2> "$work/ring.err" < /dev/null || code=1
grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring.out" || { echo "no 64-pair total"; code=1; }
[ "$(grep -c "^refusals [a-z]*: $n_refusals rows, 0 mismatched$" "$work/ring.out")" -eq 8 ] || { echo "not 8 clean refusal lines of $n_refusals rows"; code=1; }
step 3 "real ring: 64 pairs and 8 x $n_refusals refusals, 0 mismatched" "$code" "$(tail -n 1 "$work/ring.out")"

# 4. AZ-3356 AC-1, AC-2: the real drivers refuse every out-of-range number and pass the top of each range on.
code=0
limit 900 bash .github/workflows/ring-frame-drivers.test.sh > "$work/drivers.out" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS ' "$work/drivers.out")" -eq 132 ] || { echo "not 132 PASS lines"; code=1; }
grep -q '^ring-frame-drivers: all passed (8 languages, 132 checks)$' "$work/drivers.out" || code=1
step 4 "8 drivers: out-of-range numbers refused, tops passed on (132 checks)" "$code" "$(tail -n 1 "$work/drivers.out")"

# 5. AZ-3356 AC-3: the driver script is not vacuous: the Python driver of the loop start (it took a sign and handed any
# direction to the package) fails it, in a scratch copy of the tree.
code=0
mkdir -p "$work/repo" && git archive HEAD | tar -x -C "$work/repo"
py=.github/workflows/drivers/handoff_frame.py
git show "$start:$py" > "$work/repo/$py" || code=1
rc=0
limit 300 env RING_FRAME_LANGS=python PACKBIN_RING_WORK="$work/ring-py" bash "$work/repo/.github/workflows/ring-frame-drivers.test.sh" > "$work/mut.out" 2> "$work/mut.err" < /dev/null || rc=$?
[ "$rc" -eq 1 ] || { echo "the old driver exited $rc, wanted 1"; code=1; }
for c in dir-256 dir-minus-1; do grep -q "^FAIL python $c:" "$work/mut.out" || { echo "no FAIL python $c"; code=1; }; done
step 5 "the loop-start Python driver fails the new cases" "$code" "$(grep -c '^FAIL' "$work/mut.out") FAIL"

# 6. AZ-3357 AC-8: every test target of the 9 feature sets compiles with no warning (rust:1.98, as CI and step 11).
code=0
limit 1200 docker run --rm -v "$root":/src:ro -w /src/rust -e CARGO_TARGET_DIR=/tmp/t rust:1.98 bash -c '
  for set in none alloc text ecc text,ecc frame text,ecc,frame default all; do
    case "$set" in none) a=(--no-default-features) ;; default) a=() ;; all) a=(--all-features) ;; *) a=(--no-default-features --features "$set") ;; esac
    out="$(cargo check ${a[@]+"${a[@]}"} --tests 2>&1)" || { echo "BUILD-FAIL $set"; continue; }
    echo "SET $set warnings $(printf "%s\n" "$out" | grep -c "^warning:")"
  done' > "$work/check.out" 2>&1 < /dev/null || code=1
[ "$(grep -c '^SET .* warnings 0$' "$work/check.out")" -eq 9 ] || { cat "$work/check.out"; code=1; }
step 6 "Rust: 9 feature sets compile every test target with 0 warnings" "$code" "$(grep -c '^SET .* warnings 0$' "$work/check.out") of 9"

# 7. AZ-3357 AC-9: the suite runner builds the 9 sets and fails on a warning (stand-in tools).
code=0
limit 600 bash .github/workflows/run-suite.test.sh > "$work/run-suite.out" 2>&1 < /dev/null || code=1
grep -q '^run-suite.test.sh: all checks passed$' "$work/run-suite.out" || code=1
grep -q 'for rust_set in none alloc text ecc text,ecc frame text,ecc,frame default all; do' .github/workflows/run-suite.sh || { echo "run-suite.sh has not the 9 sets"; code=1; }
step 7 "run-suite.sh checks the 9 sets; a warning or a failed build fails it" "$code"

# 8. AZ-3357 AC-10: a std test file without its feature gate fails the none set (the defect of loop 76).
code=0
sed -i.bak '/^#!\[cfg(feature = "std")\]/d' "$work/repo/rust/tests/bound_names_tests.rs"
rc=0
limit 900 docker run --rm -v "$work/repo":/src:ro -w /src/rust -e CARGO_TARGET_DIR=/tmp/t rust:1.98 \
  cargo check --no-default-features --tests > "$work/ac10.out" 2>&1 < /dev/null || rc=$?
[ "$rc" -ne 0 ] || { echo "the none set compiled without the gate"; code=1; }
grep -q 'test "bound_names_tests"' "$work/ac10.out" || { echo "bound_names_tests is not named"; code=1; }
step 8 "a test file without its std gate fails the none set" "$code" "exit $rc"

# 9. Wiring: the job layout, the loop-tests stages, the ring wiring and runner tests, the report row.
code=0
for t in .github/workflows/publish-jobs.test.sh scripts/loop-tests.test.sh .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-lib.test.sh .github/workflows/report-row.test.sh; do
  limit 600 bash "$t" > "$work/$(basename "$t").out" 2>&1 < /dev/null || { echo "$t failed"; code=1; }
done
step 9 "job layout, loop-tests, ring wiring, ring-lib and report-row tests pass" "$code"

# 10. No touched source file went over 500 lines in this loop (a file that was over before is not counted).
code=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  now="$(wc -l < "$f")"
  was="$(git show "$start:$f" 2> /dev/null | wc -l)" || was=0
  if [ "$now" -gt 500 ] && [ "$was" -le 500 ]; then echo "$f grew from $was to $now lines"; code=1; fi
done < <(git diff --name-only "$start"..HEAD -- . ':(exclude)_docs' ':(exclude)fixtures')
step 10 "no touched source file went over 500 lines" "$code"

echo "smoke79: $fails failed"
[ "$fails" -eq 0 ]
