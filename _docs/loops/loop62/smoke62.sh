#!/usr/bin/env bash
# Loop 62 smoke (Field::count dropped: an Array's count is read in place; Cortex-M4F flash 8032 B to 7808 B).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. Docker is needed.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=5 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty; the pin is 7808 B and the size guard is in table.hpp"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ] && grep -q '^flash_pin=7808$' cpp/embedded/lib.sh && grep -q 'sizeof(Field) <= 32' cpp/include/packbin/table.hpp && ! grep -q 'Count count' cpp/include/packbin/table.hpp; then
  ok "clean at $(git rev-parse --short HEAD); flash_pin=7808; Field has no count pointer"
else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty files, or the pin or guard is missing"; fi

step "The M4F stage on a copy of cpp/ reports flash 7808 B, stack 496 B, no pin failure"
mkdir -p "$work/res" "$work/src"
tar -C "$repo" --exclude='cpp/build' -cf - cpp fixtures | tar -C "$work/src" -xf -
limit 900 docker run --rm -v "$work/src":/src -v "$work/res":/test-results -e SRC_ROOT=/src -e TEST_RESULTS=/test-results \
  packbin-embedded:local bash -c 'mkdir -p /test-results/embedded && cd /src && source cpp/embedded/lib.sh && source cpp/embedded/arm.sh && CURRENT_TARGET=cpp-m4f; target_m4f; echo "TARGET_EXIT $?"' < /dev/null > "$work/out.log" 2>&1
if grep -q 'delta=7808 ' "$work/out.log" && grep -q 'deepest measured pack/unpack stack=496 ' "$work/out.log" && grep -q 'TARGET_EXIT 0' "$work/out.log" && ! grep -q 'over the pin' "$work/out.log"; then
  ok "$(grep -o 'delta=[0-9]* budget=[0-9]*' "$work/out.log"); $(grep -o 'deepest measured pack/unpack stack=[0-9]*' "$work/out.log")"
else ko "the M4F figures changed"; fi

step "A pin one byte lower fails the stage by its own bytes (the pin guards the saving)"
sed -i.bak 's/^flash_pin=7808$/flash_pin=7807/' "$work/src/cpp/embedded/lib.sh"
limit 900 docker run --rm -v "$work/src":/src -v "$work/res":/test-results -e SRC_ROOT=/src -e TEST_RESULTS=/test-results \
  packbin-embedded:local bash -c 'mkdir -p /test-results/embedded && cd /src && source cpp/embedded/lib.sh && source cpp/embedded/arm.sh && CURRENT_TARGET=cpp-m4f; target_m4f; echo "TARGET_EXIT $?"' < /dev/null > "$work/out.log" 2>&1
if grep -q 'over the pin of 7807 B' "$work/out.log"; then ok "the stage reports 'over the pin of 7807 B'"; else ko "the stage did not fail against the lowered pin"; fi

step "The size guard is live on a 32-bit target: arm-none-eabi-g++ compiles table.hpp, and a copy with the limit at 28 B is refused"
printf '#include "packbin/table.hpp"\nint main() { return 0; }\n' > "$work/g.cpp"
arm_cxx() { limit 300 docker run --rm -v "$1":/src:ro -v "$work":/w packbin-embedded:local arm-none-eabi-g++ -std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror -mthumb -mcpu=cortex-m4 -I/src/cpp/include -c /w/g.cpp -o /w/g.o < /dev/null; }
mkdir -p "$work/strict" && cp -R "$work/src/cpp" "$work/strict/cpp"
sed -i.bak 's/sizeof(Field) <= 32/sizeof(Field) <= 28/' "$work/strict/cpp/include/packbin/table.hpp"
if arm_cxx "$work/src" > "$work/out.log" 2>&1 && ! arm_cxx "$work/strict" > "$work/strict.log" 2>&1 && grep -q 'Field is at most 32 bytes' "$work/strict.log"; then
  ok "the guard passes at 32 B and fails the compile at 28 B ('Field is at most 32 bytes on 32-bit targets')"
else cat "$work/strict.log" >> "$work/out.log" 2>/dev/null; ko "the guard did not behave on arm-none-eabi-g++"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

printf '\n%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
