#!/usr/bin/env bash
# Loop 58 smoke (test guards: Rust nostd corpus count, Go refusal ids, C++ dict key byte order; AZ-3160, AZ-3161, AZ-3162).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. Docker and cargo are needed.
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

step "The hostile case file still holds 75 cases and its checks pass"
if (limit 120 bash fixtures/hostile/check-cases.sh && limit 300 bash fixtures/hostile/cases.test.sh) < /dev/null > "$work/out.log" 2>&1 && grep -q 'hostile cases ok: 75' "$work/out.log"; then
  ok "75 cases; check-cases.sh and cases.test.sh pass"
else ko "the case file checks failed"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

step "Mutant (C++, AZ-3162): a signed byte compare in a copy of keys_ascending fails the new host test"
mkdir -p "$work/m" && cp -R cpp fixtures README.md "$work/m/" && rm -rf "$work/m/cpp/build"
python3 - "$work/m/cpp/src/core/pack.cpp" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = "if (at < common ? a[at] > b[at] : la >= lb)"
assert a in s
open(p, "w").write(s.replace(a, "if (at < common ? static_cast<std::int8_t>(a[at]) > static_cast<std::int8_t>(b[at]) : la >= lb)", 1))
PY
limit 900 docker run --rm -v "$work/m":/src -w /src/cpp gcc:16 sh -c 'make test 2>&1' < /dev/null > "$work/mut.log" 2>&1
if ! grep -q '^all tests passed' "$work/mut.log" && grep -q 'FAIL: pack: 7f then c2 80' "$work/mut.log"; then
  ok "the mutant fails the new test: $(grep -c 'FAIL' "$work/mut.log") failing lines, 'pack: 7f then c2 80' among them"
else cp "$work/mut.log" "$work/out.log"; ko "the signed-compare mutant was not caught by the new test"; fi

step "Mutant (Rust, AZ-3160): a loader filter that also drops letter-led lines fails the corpus count"
mkdir -p "$work/r" && rsync -a --exclude target rust fixtures "$work/r/"
python3 - "$work/r/rust/tests/nostd_hostile_tests.rs" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = ".filter(|l| !l.trim().is_empty() && !l.starts_with('#'))\n        .map(|l| {\n            let f: Vec<&str> = l.split_whitespace().collect();\n            (f[0]"
assert a in s
open(p, "w").write(s.replace(a, a.replace("!l.starts_with('#'))", "!l.starts_with('#') && !l.starts_with(|c: char| c.is_alphabetic()))"), 1))
PY
(cd "$work/r/rust" && limit 900 cargo test --features text --test nostd_hostile_tests ac1_the_fuzz < /dev/null) > "$work/rust.log" 2>&1
if grep -q 'lists 33 inputs, the loader read 0' "$work/rust.log" && grep -q 'test result: FAILED' "$work/rust.log"; then
  ok "the mutant fails: corpus.txt lists 33 inputs, the loader read 0"
else cp "$work/rust.log" "$work/out.log"; ko "the loader mutant was not caught"; fi

step "Mutant (Go, AZ-3161): a pack_error id missing from hostileRefusals is named in the failure"
mkdir -p "$work/g" && cp -R go fixtures "$work/g/"
python3 - "$work/g/go/hostile_refusals_test.go" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = '\t"pack_missing_required_value":'
assert a in s
open(p, "w").write(s.replace(a, '\t"pack_invented_extra_id": lit("x"),\n\t"pack_missing_required_value_x":', 1))
PY
limit 600 docker run --rm -v "$work/g":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'go test -count=1 -run TestHostileEveryRefusalPinsOneRule . 2>&1' < /dev/null > "$work/go.log" 2>&1
if grep -q 'Go handler pack_invented_extra_id has no case in cases.txt' "$work/go.log" && grep -q 'case pack_missing_required_value has no Go handler' "$work/go.log"; then
  ok "the mutant fails and the message names both ids"
else cp "$work/go.log" "$work/out.log"; ko "the id mutant was not named"; fi

step "Library source is unchanged since the last arm stage (7aa2d8a): Cortex-M4F figures stand"
log=test-results/embedded/cpp-m4f.log
flash="$(sed -n 's/.*AC-5 flash core (PACKBIN_NO_TEXT) + 14-field table \([0-9]*\) B of 8192.*/\1/p' "$log" | head -1)"
stack="$(sed -n 's/.*deepest pack\/unpack stack \([0-9]*\) B of 512.*/\1/p' "$log" | head -1)"
changed="$(git diff --name-only 7aa2d8a HEAD -- cpp/src cpp/include cpp/embedded rust/src rust/embedded)"
if [ -z "$changed" ] && [ -n "$flash" ] && [ -n "$stack" ] && [ "$flash" -le 8032 ] && [ "$stack" -le 512 ]; then
  ok "no library or embedded file changed; last arm log: flash $flash B of 8192 (margin $((8192 - flash)) B), stack $stack B of 512 (margin $((512 - stack)) B)"
else printf 'changed: %s\nflash %s stack %s\n' "$changed" "$flash" "$stack" > "$work/out.log"; ko "a library file changed or the arm figures are over budget"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
