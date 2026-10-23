#!/usr/bin/env bash
# Loop 63 smoke (pack.cpp: pack_u2 writes in place, bad out of line; Cortex-M4F flash 7808 B to 7724 B).
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
m4f() { limit 900 docker run --rm -v "$work/src":/src -v "$work/res":/test-results -e SRC_ROOT=/src -e TEST_RESULTS=/test-results \
  packbin-embedded:local bash -c 'mkdir -p /test-results/embedded && cd /src && source cpp/embedded/lib.sh && source cpp/embedded/arm.sh && CURRENT_TARGET=cpp-m4f; target_m4f; echo "TARGET_EXIT $?"' < /dev/null > "$work/out.log" 2>&1; }

step "No application source is dirty; the pin is 7724 B; pack.cpp has bad out of line, no local u2 buffer, no held_of"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ] && grep -q '^flash_pin=7724$' cpp/embedded/lib.sh && grep -B1 -E '^Result bad\(' cpp/src/core/pack.cpp | grep -q PACKBIN_NOINLINE \
  && ! grep -q 'raw\[16\]' cpp/src/core/pack.cpp && ! grep -q 'held_of' cpp/src/core/pack.cpp; then
  ok "clean at $(git rev-parse --short HEAD); flash_pin=7724; bad is PACKBIN_NOINLINE; pack_u2 writes in place"
else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty files, or the pin or the kept shape is missing"; fi

step "The M4F stage on a copy of cpp/ reports flash 7724 B, stack 496 B, no pin failure"
mkdir -p "$work/res" "$work/src"
tar -C "$repo" --exclude='cpp/build' -cf - cpp fixtures | tar -C "$work/src" -xf -
m4f
if grep -q 'delta=7724 ' "$work/out.log" && grep -q 'deepest measured pack/unpack stack=496 ' "$work/out.log" && grep -q 'TARGET_EXIT 0' "$work/out.log" && ! grep -q 'over the pin' "$work/out.log"; then
  ok "$(grep -o 'delta=[0-9]* budget=[0-9]*' "$work/out.log"); $(grep -o 'deepest measured pack/unpack stack=[0-9]*' "$work/out.log")"
else ko "the M4F figures changed"; fi

step "A pin one byte lower fails the stage by its own bytes (the pin guards the saving)"
sed -i.bak 's/^flash_pin=7724$/flash_pin=7723/' "$work/src/cpp/embedded/lib.sh"
m4f
if grep -q 'over the pin of 7723 B' "$work/out.log"; then ok "the stage reports 'over the pin of 7723 B'"; else ko "the stage did not fail against the lowered pin"; fi

step "pack_u2 returns the same Result as at c9ceaa7 for 12 buffer and value cases (refused child, full buffer)"
mkdir -p "$work/head/src" "$work/new/src"
for v in head new; do cp -R cpp/src/core "$work/$v/src/core"; cp -R cpp/include "$work/$v/include"; done
git show c9ceaa7:cpp/src/core/pack.cpp > "$work/head/src/core/pack.cpp"
build() { (cd "$work/$1" && g++ -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude -Isrc/core -o u2diff "$repo/_docs/loops/loop63/smoke63_u2diff.cpp" src/core/values.cpp src/core/pack.cpp src/core/unpack.cpp src/core/session.cpp && ./u2diff > out.txt); }
if build head > "$work/out.log" 2>&1 && build new >> "$work/out.log" 2>&1 && diff "$work/head/out.txt" "$work/new/out.txt" >> "$work/out.log" 2>&1 && [ "$(wc -l < "$work/new/out.txt")" -eq 12 ]; then
  ok "12 of 12 Results identical (error, offset, field, needed)"
else ko "HEAD and the new pack.cpp differ for pack_u2"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

printf '\n%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
