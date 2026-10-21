#!/usr/bin/env bash
# Loop 54 smoke (C# repeated-text reuse, C++ `when` of a skipped source, shared corpus cases; AZ-2815, AZ-2816, AZ-2823).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=7 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "The hostile case file holds 72 cases (two new pack cases) and its checks pass"
if (limit 120 bash fixtures/hostile/check-cases.sh && limit 300 bash fixtures/hostile/cases.test.sh) < /dev/null > "$work/out.log" 2>&1 && grep -q 'hostile cases ok: 72' "$work/out.log"; then
  ok "72 cases; $(grep -c . fixtures/hostile/cases.txt) lines; check-cases.sh and cases.test.sh pass"
else ko "the case file checks failed"; fi

step "The loop test stages whose files changed since step 11 pass (csharp, cpp; the others are skipped as unchanged)"
if limit 1800 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

step "Mutant on a copy of cpp/: a when that ignores a skipped source fails the corpus cases and the new tests"
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
if grep -q 'hostile pack_when_of_skipped_source: got 010005' "$work/mut.log" && grep -q '^FAIL: AC-2 plain members' "$work/mut.log" && ! grep -q '^all tests passed' "$work/mut.log"; then
  ok "the mutant fails: $(grep -c '^FAIL' "$work/mut.log") failing checks, corpus cases give 010005"
else cp "$work/mut.log" "$work/out.log"; ko "the mutant was not caught"; fi

step "C# 200 rounds of one 65,535-character text: at most 250 ms in 3 runs of each variant on both targets"
slow=0; seen=0
for t in "" "-p:PackbinTarget=netstandard2.0"; do
  for i in 1 2 3; do
    limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo $t --filter "FullyQualifiedName~RepeatedTextSpeed" --logger "console;verbosity=detailed" < /dev/null > "$work/out.log" 2>&1
    grep -q 'Failed:' "$work/out.log" && slow=$((slow + 1))
    for ms in $(grep -o 'AZ-2737 AC-1 ([a-z]*): [0-9]* ms' "$work/out.log" | awk '{print $4}'); do seen=$((seen + 1)); [ "$ms" -le 250 ] || slow=$((slow + 1)); done
  done
done
if [ "$slow" -eq 0 ] && [ "$seen" -eq 12 ]; then ok "12 timings, all within 250 ms"; else echo "slow or failed: $slow, timings seen: $seen" > "$work/out.log"; ko "timings over 250 ms or missing"; fi

step "Mutant on a copy of csharp/: a text cache that never compares the text fails the reuse tests"
mkdir -p "$work/c" && cp -R csharp fixtures README.md "$work/c/" && rm -rf "$work/c/csharp/bin" "$work/c/csharp/obj" "$work/c/csharp/tests/bin" "$work/c/csharp/tests/obj"
python3.14 - "$work/c/csharp/PackOut.cs" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = "if (_lastField is null || !utf8.AsSpan().SequenceEqual(_lastUtf8))"
assert a in s
open(p, "w").write(s.replace(a, "if (_lastField is null)", 1))
PY
(cd "$work/c" && limit 900 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo --filter "FullyQualifiedName~RepeatedTextReuse" < /dev/null > "$work/mut.log" 2>&1)
if [ "$(grep -c '^  Failed .*RepeatedTextReuse' "$work/mut.log")" -ge 5 ]; then ok "the mutant fails $(grep -c '^  Failed .*RepeatedTextReuse' "$work/mut.log") reuse tests"; else cp "$work/mut.log" "$work/out.log"; ko "the C# mutant was not caught"; fi

step "Embedded stage: Cortex-M4F within 8,192 B flash and 512 B stack, M0+, M3, s390x and AVR Uno pass"
if limit 1800 docker compose -f docker-compose.test.yml run --rm cpp-embedded < /dev/null > "$work/out.log" 2>&1; then
  flash="$(sed -n 's/.*AC-5 flash core (PACKBIN_NO_TEXT) + 14-field table \([0-9]*\) B of 8192.*/\1/p' "$work/out.log" | head -1)"
  stack="$(sed -n 's/.*deepest pack\/unpack stack \([0-9]*\) B of 512.*/\1/p' "$work/out.log" | head -1)"
  if [ -n "$flash" ] && [ -n "$stack" ] && [ "$flash" -le 8192 ] && [ "$stack" -le 512 ] && [ "$(grep -c '^=== cpp-.*: PASS' "$work/out.log")" -eq 5 ]; then
    ok "flash $flash B of 8192 (margin $((8192 - flash)) B), stack $stack B of 512 (margin $((512 - stack)) B), 5 of 5 targets pass"
  else ko "a budget or a target failed (flash '$flash', stack '$stack')"; fi
else ko "the embedded stage failed"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
