#!/usr/bin/env bash
# Loop 78 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop78/smoke78.sh
# Needs Docker (the Go driver), dotnet 10, a JDK 17+, cargo, python3.10+, node 22 and Swift on PATH; about 3 minutes on a quiet
# host (check `uptime` first). Step 11 of the loop (scripts/loop-tests.sh --all) is the total run; this script re-checks what the
# loop delivered (refusal rows by name, AZ-3354; strict drivers and writer blame, AZ-3355) with the real drivers.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke78-failed-logs"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke78: logs kept in $keep"; fi
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
cases=fixtures/frame/ring-cases.txt
n_rs="$(grep -c '^refuse-seal ' "$cases")"
n_ro="$(grep -c '^refuse-open ' "$cases")"
n_rm="$(grep -c '^refuse-mac ' "$cases")"
n_fit="$(grep -c '^seal fit\.' "$cases")"
n_refusals="$(grep -cE '^(open|verify|refuse-seal|refuse-open|refuse-mac) ' "$cases")"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3354 AC-1: the rows are there; the self-test, which needs no toolchain, passes with its new bad-driver cases.
code=0
[ "$n_rs" -eq 11 ] && [ "$n_ro" -eq 6 ] && [ "$n_rm" -eq 5 ] && [ "$n_fit" -ge 2 ] && [ "$n_refusals" -eq 38 ] \
  || { echo "rows: refuse-seal $n_rs refuse-open $n_ro refuse-mac $n_rm fit $n_fit refusals $n_refusals"; code=1; }
limit 300 bash .github/workflows/ring-frame.test.sh > "$work/selftest.out" 2>&1 < /dev/null || code=1
grep -q '^ring-frame.test: all passed$' "$work/selftest.out" || code=1
for c in dir0-aborts unloaded-direction-accepted fit-refused writer-prints-word mac-writer-prints-word refuse-seal-name-changed refuse-mac-name-changed; do
  grep -q "^PASS $c\$" "$work/selftest.out" || { echo "no PASS $c"; code=1; }
done
step 2 "22 refusal rows, 38 per language; self-test passes with the bad-driver cases" "$code" "$(grep -c '^PASS' "$work/selftest.out") PASS"

# 3. AZ-3354 AC-3 to AC-6: the real ring, all 8 languages.
code=0
limit 900 bash .github/workflows/ring-frame.sh > "$work/ring.out" 2> "$work/ring.err" < /dev/null || code=1
grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring.out" || { echo "no 64-pair total"; code=1; }
[ "$(grep -c '^pair .*, 0 mismatched$' "$work/ring.out")" -eq 64 ] || { echo "not 64 clean pairs"; code=1; }
[ "$(grep -c "^refusals [a-z]*: $n_refusals rows, 0 mismatched$" "$work/ring.out")" -eq 8 ] || { echo "not 8 clean refusal lines of $n_refusals rows"; code=1; }
step 3 "real ring: 64 pairs and 8 x $n_refusals refusals, 0 mismatched" "$code" "$(tail -n 1 "$work/ring.out")"

# 4. AZ-3355 AC-2 to AC-4: the real drivers refuse malformed lines.
code=0
limit 900 bash .github/workflows/ring-frame-drivers.test.sh > "$work/drivers.out" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS ' "$work/drivers.out")" -eq 44 ] || { echo "not 44 PASS lines"; code=1; }
grep -q '^ring-frame-drivers: all passed (8 languages)$' "$work/drivers.out" || code=1
[ "$(grep -c ', _ := strconv' .github/workflows/drivers/handoff-go/frame.go)" -eq 0 ] || { echo "the Go driver discards a parse error"; code=1; }
step 4 "8 drivers refuse malformed lines (44 runs); Go keeps no parse error" "$code" "$(tail -n 1 "$work/drivers.out")"

# 5. The driver script is not vacuous: the TypeScript driver of the AZ-3354 commit (lenient) fails it, in a scratch copy of the tree.
code=0
mkdir -p "$work/repo" && git archive HEAD | tar -x -C "$work/repo"
ln -s "$root/typescript/node_modules" "$work/repo/typescript/node_modules" # the dependencies of the TypeScript package, not tracked
ts=.github/workflows/drivers/handoff-frame.ts
git show "$(git log --format=%h -n 1 --grep='^\[AZ-3354\]' -- "$ts")":"$ts" > "$work/repo/$ts" || code=1
rc=0
limit 300 env RING_FRAME_LANGS=typescript PACKBIN_RING_WORK="$work/ring-ts" bash "$work/repo/.github/workflows/ring-frame-drivers.test.sh" > "$work/mut.out" 2> "$work/mut.err" < /dev/null || rc=$?
[ "$rc" -eq 1 ] || { echo "the mutant exited $rc, wanted 1"; code=1; }
grep -q '^FAIL typescript bad-digit' "$work/mut.out" || { echo "no FAIL typescript bad-digit"; code=1; }
step 5 "a lenient TypeScript driver fails the driver script and names the case" "$code"

# 6. Wiring: the job layout, the loop-tests stages, the ring wiring and ring runner tests; the new script is in the ring job and in step 11.
code=0
for t in .github/workflows/publish-jobs.test.sh scripts/loop-tests.test.sh .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-lib.test.sh; do
  limit 600 bash "$t" > "$work/$(basename "$t").out" 2>&1 < /dev/null || { echo "$t failed"; code=1; }
done
grep -q 'bash .github/workflows/ring-frame-drivers.test.sh' .github/workflows/test.yml || { echo "test.yml has no driver step"; code=1; }
for s in ring-frame.sh ring-frame-drivers.test.sh ring-frame.test.sh; do
  grep -q "$s" scripts/loop-tests.sh || { echo "loop-tests.sh does not run $s"; code=1; }
done
step 6 "job wiring, loop-tests, ring wiring and runner tests pass; new script wired" "$code"

# 7. No touched source file went over 500 lines in this loop (a file that was over before is not counted).
code=0
base="$(git log --format=%h -n 1 --grep='^Start: frame-ring-refusals')"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  now="$(wc -l < "$f")"
  was="$(git show "$base^:$f" 2> /dev/null | wc -l)" || was=0
  if [ "$now" -gt 500 ] && [ "$was" -le 500 ]; then echo "$f grew from $was to $now lines"; code=1; fi
done < <(git diff --name-only "$base^"..HEAD -- . ':(exclude)_docs' ':(exclude)fixtures')
step 7 "no touched source file went over 500 lines" "$code"

echo "smoke78: $fails failed"
[ "$fails" -eq 0 ]
