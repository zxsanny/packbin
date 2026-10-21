#!/usr/bin/env bash
# Loop 55 smoke (C++ `when` chain stack, bool source behind a clear `when`, repeated-text headroom; AZ-3132, AZ-3133, AZ-3134, AZ-3141).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. No network.
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

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "The hostile case file holds 75 cases (three new bool-source pack cases) and its checks pass"
if (limit 120 bash fixtures/hostile/check-cases.sh && limit 300 bash fixtures/hostile/cases.test.sh) < /dev/null > "$work/out.log" 2>&1 && grep -q 'hostile cases ok: 75' "$work/out.log"; then
  ok "75 cases; check-cases.sh and cases.test.sh pass"
else ko "the case file checks failed"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

step "Mutant on a copy of cpp/: a when that ignores a skipped source fails the bool-source corpus cases"
mkdir -p "$work/m" && cp -R cpp fixtures README.md "$work/m/" && rm -rf "$work/m/cpp/build"
python3.14 - "$work/m/cpp/src/core/values.cpp" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = "value == f.eq &&\n         !source_skipped(t, f, obj);"
assert a in s
open(p, "w").write(s.replace(a, "value == f.eq;", 1))
PY
limit 900 docker run --rm -v "$work/m":/src -w /src/cpp gcc:16 sh -c 'make test 2>&1' < /dev/null > "$work/mut.log" 2>&1
if grep -q 'pack_when_of_skipped_bool_source' "$work/mut.log" && ! grep -q '^all tests passed' "$work/mut.log"; then
  ok "the mutant fails: $(grep -c '^FAIL' "$work/mut.log") failing checks, among them pack_when_of_skipped_bool_source"
else cp "$work/mut.log" "$work/out.log"; ko "the mutant was not caught"; fi

step "Embedded stage (the step above ran it): Cortex-M4F within 8,192 B flash and 512 B stack, both chains equal to Python"
log=test-results/embedded/cpp-m4f.log
flash="$(sed -n 's/.*AC-5 flash core (PACKBIN_NO_TEXT) + 14-field table \([0-9]*\) B of 8192.*/\1/p' "$log" | head -1)"
stack="$(sed -n 's/.*deepest pack\/unpack stack \([0-9]*\) B of 512.*/\1/p' "$log" | head -1)"
if [ -n "$flash" ] && [ -n "$stack" ] && [ "$flash" -le 8192 ] && [ "$stack" -le 512 ] \
  && grep -q '^CHAIN_FAILURES 0' "$log" && grep -q '^FLAG_CHAIN_FAILURES 0' "$log" \
  && [ ! -e test-results/embedded/cpp-m0plus.failed ] && [ ! -e test-results/embedded/cpp-m3-qemu.failed ] \
  && [ ! -e test-results/embedded/cpp-m4f.failed ] && [ ! -e test-results/embedded/cpp-s390x.failed ] \
  && [ ! -e test-results/embedded/cpp-avr-uno.failed ]; then
  ok "flash $flash B of 8192 (margin $((8192 - flash)) B), stack $stack B of 512 (margin $((512 - stack)) B), CHAIN_FAILURES 0, FLAG_CHAIN_FAILURES 0"
else ko "a budget or a chain check failed (flash '$flash', stack '$stack')"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
