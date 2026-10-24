#!/usr/bin/env bash
# Loop 68 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop68/smoke68.sh
# Needs Docker with the packbin-embedded image (the arm embedded stage) and takes about 1 minute with a warm cache.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}

# 1. AC-1, AC-2, AC-3, AC-4, AC-5, AC-7: the arm stage passes with six rows and the M33F figures within the ceilings.
docker compose -f docker-compose.test.yml run --rm cpp-embedded > "$work/arm.log" 2>&1 < /dev/null; code=$?
flash="$(sed -n 's/^NOTE Cortex-M33F whole core: all-kinds image flash \([0-9]*\) B of 65536.*/\1/p' "$work/arm.log" | head -n 1)"
stack="$(sed -n 's/^NOTE deepest pack\/unpack stack \([0-9]*\) B of 8192.*/\1/p' "$work/arm.log" | head -n 1)"
[ "$(grep -c '^=== cpp-[a-z0-9-]*: PASS' "$work/arm.log")" -eq 6 ] || code=1
grep -q '^=== cpp-m33f: PASS' "$work/arm.log" || code=1
grep -q 'embedded stage arm: 0 target(s) failed' "$work/arm.log" || code=1
grep -q 'core data+bss 0 B' "$work/arm.log" || code=1
grep -q 'table 7712 B of 8192 (pin 7712 B); deepest pack/unpack stack 540 B' "$work/arm.log" || code=1
step 1 "AC-1..5 AC-7 arm stage: 6 rows pass, M33F flash ${flash:-?} B stack ${stack:-?} B" "$code" "$(tail -n 3 "$work/arm.log")"

# 2. AC-3, AC-4: the pins are the measured figures and the ceilings are 64 KB and 8 KB.
code=1
if [ -n "$flash" ] && [ -n "$stack" ] && grep -q "^m33f_flash_pin=$flash\$" cpp/embedded/lib.sh \
  && grep -q "^m33f_stack_pin=$stack\$" cpp/embedded/lib.sh && grep -q '^m33f_flash_budget=65536$' cpp/embedded/lib.sh \
  && grep -q '^m33f_stack_budget=8192$' cpp/embedded/lib.sh; then code=0; fi
step 2 "AC-3 AC-4 pins equal the measured figures, ceilings 65,536 B and 8,192 B" "$code"

# 3. AC-2: the packet equals the Cortex-M3 packet, the runner ran 290 vectors (22 of them session vectors) on mps2-an505.
code=1
if cmp -s test-results/embedded/m3-all-kinds.hex test-results/embedded/m33f-all-kinds.hex \
  && grep -q '^qemu mps2-an505 exit 0$' "$work/arm.log" && grep -q 'vectors session_tests.cpp asserted=22 run=22' "$work/arm.log" \
  && [ "$(grep -c 'vectors run 290 asserted 290' "$work/arm.log")" -ge 3 ]; then code=0; fi
step 3 "AC-2 M33F packet equals the M3 packet; 290 vectors on mps2-an505" "$code"

# 4. AC-6: a pin 1 B low and a ceiling below the figure fail the row naming the figure.
mkdir -p "$work/t/fixtures" "$work/t/.github" "$work/res/embedded"
rsync -a --exclude build cpp "$work/t/"
cp fixtures/golden.hex "$work/t/fixtures/"
cp test-results/embedded/m3-all-kinds.hex "$work/res/embedded/"
run_m33f() { # run_m33f <sed expression on lib.sh>
  perl -pi -e "$1" "$work/t/cpp/embedded/lib.sh"
  docker run --rm -v "$work/t":/src -v "$work/res":/res -w /src -e SRC_ROOT=/src -e TEST_RESULTS=/res packbin-embedded:local bash -c '
    here=/src/cpp/embedded; source "$here/lib.sh"; source "$here/arm.sh"; mkdir -p "$out"; CURRENT_TARGET=cpp-m33f; : > "$out/cpp-m33f.msg"
    ( set -e; target_m33f ) 2>&1; echo "rc=$?"' < /dev/null 2>&1
}
code=0
out="$(run_m33f "s/^m33f_stack_pin=.*/m33f_stack_pin=$((stack - 1))/")"
printf '%s' "$out" | grep -q "M33F stack ${stack} B measured is over the pin of $((stack - 1)) B" || code=1
out="$(run_m33f "s/^m33f_stack_pin=.*/m33f_stack_pin=$stack/; s/^m33f_flash_pin=.*/m33f_flash_pin=$((flash - 1))/")"
printf '%s' "$out" | grep -q "M33F flash ${flash} B measured is over the pin of $((flash - 1)) B" || code=1
out="$(run_m33f "s/^m33f_flash_pin=.*/m33f_flash_pin=$flash/; s/^m33f_stack_budget=.*/m33f_stack_budget=$((stack - 1))/")"
printf '%s' "$out" | grep -q "M33F stack ${stack} B over $((stack - 1)) B" || code=1
step 4 "AC-6 a pin 1 B low and a ceiling below the figure fail the row" "$code"

# 5. AC-8: the harness self-tests list the new row and pass.
code=0
bash cpp/embedded/run-parts.test.sh > "$work/parts.log" 2>&1 < /dev/null || code=1
bash cpp/embedded/lib.test.sh > "$work/lib.log" 2>&1 < /dev/null || code=1
grep -q "cpp-m33f target_m33f -" cpp/embedded/run-parts.test.sh || code=1
step 5 "AC-8 run-parts.test.sh and lib.test.sh pass with cpp-m33f listed" "$code" "$(tail -n 2 "$work/parts.log" "$work/lib.log")"

# 6. AC-10: the core source is untouched since the loop 67 close.
code=0
git diff --quiet 4151a90 -- cpp/src cpp/include || code=1
step 6 "AC-10 0 changes in cpp/src and cpp/include since 4151a90" "$code"

echo "smoke68: $fails failed"
[ "$fails" -eq 0 ]
