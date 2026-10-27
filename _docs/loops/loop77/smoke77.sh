#!/usr/bin/env bash
# Loop 77 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop77/smoke77.sh
# Needs Docker (the Go driver), dotnet 10, a JDK 17+, cargo, python3.10+, node 22 and Swift on PATH; about 3 minutes on a quiet
# host (check `uptime` first). Step 11 of the loop (scripts/loop-tests.sh --all) is the total run; this script re-checks what the
# loop delivered (the frame ring of AZ-3338 and its tamper and wide rows, AZ-3341) with the real drivers.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke77-failed-logs"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke77: logs kept in $keep"; fi
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
n_seal="$(grep -c '^seal ' "$cases")"
n_mac="$(grep -c '^mac ' "$cases")"
n_open="$(grep -c '^open ' "$cases")"
n_verify="$(grep -c '^verify ' "$cases")"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3341: the rows are there (tamper and wide) and the self-test, which needs no toolchain, passes with its permissive-reader cases.
code=0
[ "$n_seal" -ge 20 ] && [ "$n_mac" -ge 10 ] && [ "$n_open" -ge 8 ] && [ "$n_verify" -ge 4 ] || { echo "rows: seal $n_seal mac $n_mac open $n_open verify $n_verify"; code=1; }
limit 300 bash .github/workflows/ring-frame.test.sh > "$work/selftest.out" 2>&1 < /dev/null || code=1
grep -q '^ring-frame.test: all passed$' "$work/selftest.out" || code=1
grep -q '^PASS open-permissive$' "$work/selftest.out" && grep -q '^PASS verify-permissive$' "$work/selftest.out" || { echo "no permissive-reader case"; code=1; }
step 2 "rows present; self-test passes incl. permissive readers" "$code" "seal $n_seal, mac $n_mac, open $n_open, verify $n_verify; $(grep -c '^PASS' "$work/selftest.out") PASS"

# 3. AZ-3338 AC-1 and AC-2, AZ-3341 AC-1 to AC-9 and AC-11: the real ring, all 8 languages.
code=0
limit 900 bash .github/workflows/ring-frame.sh > "$work/ring.out" 2> "$work/ring.err" < /dev/null || code=1
grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring.out" || { echo "no 64-pair total"; code=1; }
[ "$(grep -c '^pair .*, 0 mismatched$' "$work/ring.out")" -eq 64 ] || { echo "not 64 clean pairs"; code=1; }
want=$((n_open + n_verify))
[ "$(grep -c "^refusals [a-z]*: $want rows, 0 mismatched$" "$work/ring.out")" -eq 8 ] || { echo "not 8 clean refusal lines of $want rows"; code=1; }
grep -q "^ring-frame: $n_seal seal rows$" "$work/ring.out" || code=1
step 3 "real ring: 64 pairs and 8 x $want refusals, 0 mismatched" "$code" "$(tail -n 1 "$work/ring.out")"

# 4. A real driver with a defect turns the ring red (AZ-3341 AC-9): the committed tree, the TypeScript fix removed, TypeScript only.
code=0
mkdir -p "$work/repo" && git archive HEAD | tar -x -C "$work/repo"
ln -s "$root/typescript/node_modules" "$work/repo/typescript/node_modules" # the dependencies of the TypeScript package, not tracked
perl -0pi -e 's/  if \("field" in result\) return "short";[^\n]*\n//' "$work/repo/.github/workflows/drivers/handoff-frame.ts"
! grep -q '"field" in result' "$work/repo/.github/workflows/drivers/handoff-frame.ts" || { echo "the mutation did not apply"; code=1; }
rc=0
limit 300 env RING_FRAME_LANGS=typescript PACKBIN_RING_WORK="$work/ring-ts" bash "$work/repo/.github/workflows/ring-frame.sh" > "$work/mut.out" 2> "$work/mut.err" < /dev/null || rc=$?
[ "$rc" -eq 1 ] || { echo "the mutant ring exited $rc, wanted 1"; code=1; }
grep -q 'typescript: E3.short open gave error, wanted ShortPacket' "$work/mut.out" || { echo "no ShortPacket message"; code=1; }
step 4 "TypeScript without the ShortPacket fix fails the ring and names the row" "$code"

# 5. Readers of the changed shapes: the suite runner test (14 cargo runs incl. --all-features), the job wiring and the ring wiring tests.
code=0
for t in .github/workflows/run-suite.test.sh .github/workflows/publish-jobs.test.sh .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-lib.test.sh; do
  limit 600 bash "$t" > "$work/$(basename "$t").out" 2>&1 < /dev/null || { echo "$t failed"; code=1; }
done
grep -q -e '--all-features' .github/workflows/run-suite.sh || { echo "run-suite.sh has no --all-features run"; code=1; }
step 5 "run-suite, job wiring, ring wiring and ring runner tests pass" "$code"

# 6. AZ-3338 AC-7 and AZ-3341 AC-10: the Swift Kind comment names the seven frame kinds and the Pascal case spelling.
code=0
head -n 14 swift/Sources/Packbin/PackbinError.swift > "$work/comment.txt"
for w in short_packet bad_value too_long buffer_full tag_mismatch duplicate too_old ShortPacket BadValue TooLong BufferFull TagMismatch Duplicate TooOld; do
  grep -q "\`$w\`" "$work/comment.txt" || { echo "the comment lacks $w"; code=1; }
done
step 6 "Swift PackbinError.Kind comment names the 7 frame kinds in both spellings" "$code"

# 7. No touched source file grew past 500 lines (fixtures and docs are data).
code=0
big=""
for f in scripts/frame/ring_frame.py .github/workflows/ring-frame.sh .github/workflows/ring-frame.test.sh .github/workflows/drivers/handoff-frame.ts \
  .github/workflows/drivers/handoff_frame.py .github/workflows/drivers/HandoffFrame.java .github/workflows/drivers/csharp/HandoffFrame.cs \
  .github/workflows/drivers/handoff-go/frame.go .github/workflows/drivers/handoff-rust/src/frame.rs \
  .github/workflows/drivers/handoff-swift/Sources/handoff-swift/Frame.swift swift/Sources/Packbin/PackbinError.swift; do
  if [ "$(wc -l < "$f")" -gt 500 ]; then big="$big $f"; code=1; fi
done
step 7 "no touched source file over 500 lines" "$code" "$big"

echo "smoke77: $fails failed"
[ "$fails" -eq 0 ]
