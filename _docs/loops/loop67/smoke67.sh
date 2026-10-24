#!/usr/bin/env bash
# Loop 67 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop67/smoke67.sh
# Needs Docker (the arm embedded stage, gcc:16) and takes about 2 minutes.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}

# 1. AC-1, AC-2, AC-4: the arm embedded stage passes; stack at most 548 B, flash at most 7,724 B, 290 of 290 vectors.
docker compose -f docker-compose.test.yml run --rm cpp-embedded > "$work/arm.log" 2>&1 < /dev/null; code=$?
stack="$(sed -n 's/^NOTE deepest pack\/unpack stack \([0-9]*\) B.*/\1/p' "$work/arm.log" | head -n 1)"
flash="$(sed -n 's/^NOTE AC-5 flash core.* \([0-9]*\) B of 8192.*/\1/p' "$work/arm.log" | head -n 1)"
[ -n "$stack" ] && [ -n "$flash" ] && [ "$stack" -le 548 ] && [ "$flash" -le 7724 ] || code=1
grep -q 'vectors run 290 asserted 290' "$work/arm.log" || code=1
grep -q 'embedded stage arm: 0 target(s) failed' "$work/arm.log" || code=1
step 1 "AC-1 AC-2 AC-4 arm stage: stack ${stack:-?} B, flash ${flash:-?} B" "$code" "$(tail -n 3 "$work/arm.log")"

# 2. AC-5: the pins are the measured figures.
code=1
if grep -q '^stack_pin=540$' cpp/embedded/lib.sh && grep -q '^flash_pin=7712$' cpp/embedded/lib.sh \
  && [ "${stack:-0}" -eq 540 ] && [ "${flash:-0}" -eq 7712 ]; then code=0; fi
step 2 "AC-5 stack_pin 540 and flash_pin 7712 equal the measured figures" "$code"

# 3. AC-3: the new when-scope test fails on a copy of unpack.cpp that never brings the outer bytes back.
mkdir -p "$work/t"
rsync -a --exclude build cpp "$work/t/"
python3 - "$work/t/cpp/src/core/unpack.cpp" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = "    std::memcpy(w.flag_bytes, keep, sizeof(outer));\n"
assert a in s
open(p, "w").write(s.replace(a, "    (void)keep;\n"))
PY
out="$(env PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path 2>/dev/null)" make -C "$work/t/cpp" test 2>&1)"; code=$?
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q 'FAIL: when scope: the outer byte serves the bit after the when'; then code=0; else code=1; fi
step 3 "AC-3 a copy without the restore fails the new when-scope test" "$code"

# 4. AC-3: unpack.cpp compiles clean in gcc:16 at -O1, -O2, -O3 and -Os (the conditionally copied array warned there).
code=0
for o in -O1 -O2 -O3 -Os; do
  docker run --rm -v "$root":/src:ro -w /src/cpp gcc:16 g++ -std=c++17 "$o" -Wall -Wextra -Werror -Iinclude -fno-exceptions -fno-rtti \
    -Iembedded/common -c src/core/unpack.cpp -o /dev/null > "$work/gcc$o.log" 2>&1 < /dev/null || { code=1; tail -n 3 "$work/gcc$o.log"; }
done
step 4 "AC-3 unpack.cpp warning-free in gcc:16 at four optimisation levels" "$code"

# 5. AC-1: a flag-scope level is one 56 B frame (was 80 B: 48 B plus a 32 B with_outer_flags frame).
code=1
su=cpp/build/embedded/m4f/core-unpack.su
if [ -f "$su" ] && awk -F'\t' '/unpack_children/ { print $2 }' "$su" | grep -qx 56 && ! grep -q 'with_outer_flags.*unpack_children' "$su"; then code=0; fi
step 5 "AC-1 unpack_children frame is 56 B and no with_outer_flags<unpack_children> frame is left" "$code"

echo "smoke67: $fails failed"
[ "$fails" -eq 0 ]
