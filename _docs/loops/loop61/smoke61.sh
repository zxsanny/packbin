#!/usr/bin/env bash
# Loop 61 smoke (pack side held_of: measured on the Cortex-M4F image, rejected for flash; the source stays at HEAD).
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

# The M4F target of cpp/embedded/arm.sh in packbin-embedded on a copy of cpp/ at $1; log to $2.
m4f() {
  limit 900 docker run --rm -v "$1":/src -v "$work/res":/test-results -e SRC_ROOT=/src -e TEST_RESULTS=/test-results \
    packbin-embedded:local bash -c 'mkdir -p /test-results/embedded && cd /src && source cpp/embedded/lib.sh && source cpp/embedded/arm.sh && CURRENT_TARGET=cpp-m4f; target_m4f; echo "TARGET_EXIT $?"' < /dev/null > "$2" 2>&1
}

step "No application source is dirty and the library and embedded files are those of the last arm stage (7aa2d8a)"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ] && git merge-base --is-ancestor 7aa2d8a HEAD && git diff --quiet 7aa2d8a HEAD -- cpp/src cpp/include cpp/embedded; then
  ok "clean at $(git rev-parse --short HEAD); cpp/src, cpp/include, cpp/embedded identical to 7aa2d8a"
else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty files, or the library changed since 7aa2d8a"; fi

mkdir -p "$work/res" "$work/head" "$work/cand"
tar -C "$repo" --exclude='cpp/build' -cf - cpp | tar -C "$work/head" -xf -
tar -C "$repo" --exclude='cpp/build' -cf - cpp | tar -C "$work/cand" -xf -

step "Baseline: the M4F stage at HEAD reports flash 8032 B, stack 504 B, no pin failure"
m4f "$work/head" "$work/out.log"
if grep -q 'delta=8032 ' "$work/out.log" && grep -q 'deepest measured pack/unpack stack=504 ' "$work/out.log" && grep -q 'TARGET_EXIT 0' "$work/out.log" && ! grep -q 'over the pin' "$work/out.log"; then
  ok "$(grep -o 'delta=[0-9]* budget=[0-9]*' "$work/out.log"); $(grep -o 'deepest measured pack/unpack stack=[0-9]*' "$work/out.log")"
else ko "the baseline figures changed"; fi

step "Candidate A (patch in this folder): the stage reports flash 8104 B and rejects it against the pin"
( cd "$work/cand" && git init -q . >/dev/null 2>&1; git apply -p1 "$repo/_docs/loops/loop61/pack_held_of_a.patch" ) > "$work/apply.log" 2>&1
m4f "$work/cand" "$work/cand.log"
if grep -q 'delta=8104 ' "$work/cand.log" && grep -q 'NOTE FAIL flash 8104 B measured is over the pin of 8032 B' "$work/cand.log"; then
  ok "$(grep -o 'delta=[0-9]* budget=[0-9]*' "$work/cand.log"); the stage fails 'over the pin of 8032 B'"
else cat "$work/apply.log" "$work/cand.log" > "$work/out.log"; ko "the candidate did not behave as recorded"; fi

step "Candidate A pack stack is 8 B lower and the unpack stack is unchanged (chain 404, flag chain 440, round chain 492)"
if grep -q '^CHAIN_PACK_STACK 404' "$work/cand.log" && grep -q '^FLAG_CHAIN_PACK_STACK 440' "$work/cand.log" && grep -q '^ROUND_CHAIN_PACK_STACK 492' "$work/cand.log" && grep -q '^FLAG_CHAIN_UNPACK_STACK 540' "$work/cand.log"; then
  ok "pack 404 / 440 / 492, unpack flag chain 540 as at HEAD"
else grep STACK "$work/cand.log" > "$work/out.log"; ko "stack figures differ from the record"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

printf '\n%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
