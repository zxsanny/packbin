#!/usr/bin/env bash
# Loop 60 smoke (test cleanups: Rust nostd corpus count by name, kind and lowercase hex; C++ dict key pairs print the Error; two tasks, Jira keys pending).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. Docker and cargo are needed.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=6 n=0 passed=0

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

step "Rust: a comment and an extra valid input pass; an upper-case hex line, a bad kind and a letter-dropping loader fail"
mkdir -p "$work/r" && rsync -a --exclude target rust fixtures "$work/r/"
rt() { (cd "$work/r/rust" && limit 900 cargo test --features text --test nostd_hostile_tests ac1_the_fuzz < /dev/null) 2>&1; }
corpus="$work/r/fixtures/hostile/fuzz/corpus.txt"
cp "$corpus" "$work/corpus.good"
printf '# note abcd\n' >> "$corpus"
rt > "$work/rust1.log"
cp "$work/corpus.good" "$corpus"; printf 'hostile_extra_line  negative_count  01ff61\n' >> "$corpus"
rt > "$work/rust2.log"
cp "$work/corpus.good" "$corpus"; printf 'hostile_upper position ABCD\n' >> "$corpus"
rt > "$work/rust3.log"
cp "$work/corpus.good" "$corpus"; printf 'ring_badkind Bad-Kind 01\n' >> "$corpus"
rt > "$work/rust4.log"
cp "$work/corpus.good" "$corpus"
python3 - "$work/r/rust/tests/nostd_hostile_tests.rs" <<'PY' || echo "mutation anchor not found" >> "$work/out.log"
import sys
p = sys.argv[1]
s = open(p).read()
a = ".filter(|l| !l.trim().is_empty() && !l.starts_with('#'))\n        .map(|l| {\n            let f: Vec<&str> = l.split_whitespace().collect();\n            (f[0]"
assert a in s
open(p, "w").write(s.replace(a, a.replace("!l.starts_with('#'))", "!l.starts_with('#') && !l.starts_with(|c: char| c.is_alphabetic()))"), 1))
PY
rt > "$work/rust5.log"
if grep -q 'test result: ok' "$work/rust1.log" && grep -q 'test result: ok' "$work/rust2.log" && grep -q 'lists 33 inputs, the loader read 34' "$work/rust3.log" && grep -q 'lists 33 inputs, the loader read 34' "$work/rust4.log" && grep -q 'lists 33 inputs, the loader read 0' "$work/rust5.log"; then
  ok "comment and extra line pass; upper-case hex and bad kind fail 'lists 33 inputs, the loader read 34'; letter-dropping loader fails 'read 0'"
else cat "$work"/rust[1-5].log > "$work/out.log"; ko "a Rust count check did not behave"; fi

step "C++: a flipped pair prints both Error names and a 5-byte key trips the put_key guard without packing"
mkdir -p "$work/m" && cp -R cpp fixtures README.md "$work/m/" && rm -rf "$work/m/cpp/build"
cp "$work/m/cpp/tests/core/dict_order_host_tests.cpp" "$work/good.cpp"
cpt() { limit 900 docker run --rm -v "$work/m":/src -w /src/cpp gcc:16 sh -c 'make clean >/dev/null; make test 2>&1' < /dev/null; }
sed -i.bak 's|expect_pair(Error::BadValue, "ab", 2, "a", 1, "ab then a");|expect_pair(Error::Ok, "ab", 2, "a", 1, "ab then a");|' "$work/m/cpp/tests/core/dict_order_host_tests.cpp"
cpt > "$work/cpp1.log" 2>&1
cp "$work/good.cpp" "$work/m/cpp/tests/core/dict_order_host_tests.cpp"
sed -i.bak 's|expect_pair(Error::BadValue, "a", 1, "a", 1, "a twice");|expect_pair(Error::BadValue, "abcde", 5, "a", 1, "a twice");|' "$work/m/cpp/tests/core/dict_order_host_tests.cpp"
cpt > "$work/cpp2.log" 2>&1
if grep -q 'FAIL: pack: ab then a: got BadValue, want Ok' "$work/cpp1.log" && grep -q 'FAIL: put_key: the key fits its Text' "$work/cpp2.log" && grep -q 'FAIL: pack: a twice: got TooLong, want BadValue' "$work/cpp2.log" && ! grep -q '^all tests passed' "$work/cpp1.log" "$work/cpp2.log"; then
  ok "the flipped pair fails as 'pack: ab then a: got BadValue, want Ok'; the long key fails the guard and the pair reports TooLong"
else cat "$work/cpp1.log" "$work/cpp2.log" > "$work/out.log"; ko "a C++ mutant was not caught"; fi

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
