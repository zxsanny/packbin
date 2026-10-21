#!/usr/bin/env bash
# Loop 53 smoke (Rust heap-free API: session, hostile corpus, differential proof, raw memo; AZ-2756, AZ-2757). One line
# per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. No network (everything builds from disk).
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f "$repo/rust/embedded/build/smoke-limits.txt"' EXIT
N=9 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
result_of() { grep '^test result' "$1" | awk '{p+=$4; f+=$6} END {print p " passed, " f " failed"}'; }
clean_result() { [ "$(result_of "$1" | awk '{print $3}')" = "0" ]; }

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "The crate builds as no_std with session, with every feature, and the flat heap-free tests pass"
if (cd rust && limit 600 cargo build --no-default-features && limit 600 cargo build --no-default-features --features session && limit 600 cargo build --no-default-features --features text,ecc,session && limit 600 cargo test --no-default-features --test nostd_flat_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 12 passed' "$work/out.log"; then ok "four builds; $(result_of "$work/out.log")"; else ko "a no_std build or the flat tests failed"; fi

step "The default Rust suite passes"
if (cd rust && limit 900 cargo test) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then
  ok "$(result_of "$work/out.log") in $(grep -c '^test result' "$work/out.log") targets"
else ko "the default suite failed"; fi

step "AZ-2756 AC-1..AC-3: the session gives the bytes of std PackSession, opens std packets, refuses bad arguments (no std, and std with ecc)"
if (cd rust && limit 600 cargo test --no-default-features --features session --test nostd_session_tests && limit 600 cargo test --features session,ecc --test nostd_session_tests) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then ok "$(result_of "$work/out.log")"; else ko "the session tests failed"; fi

step "AZ-2757 AC-1, AC-2, AC-4: hostile corpus, pack cases, fixture differential, raw memo, documents"
if (cd rust && limit 900 cargo test --features text,ecc --test nostd_hostile_tests --test nostd_hostile_pack_tests --test nostd_fixture_differential_tests --test nostd_raw_repeat_tests --test nostd_docs_tests) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then
  ok "$(result_of "$work/out.log") (15 unpack, 2 limit, 14 construct, 20 pack cases, 346 + 42 text rows, 35 ECC rows, corpus and mutations)"
else ko "the AZ-2757 tests failed"; fi

step "AZ-2757 AC-3: the crate packages as the publish script does, and builds with default features off"
stage="$work/stage"; mkdir -p "$stage"
rsync -a --exclude target --exclude embedded/build --exclude embedded/probe/target rust/ "$stage/" && cp README.md "$stage/README.md"
if (cd "$stage" && limit 600 cargo publish --dry-run --allow-dirty && limit 300 cargo build --no-default-features) < /dev/null > "$work/out.log" 2>&1 && grep -q 'aborting upload due to dry run' "$work/out.log"; then ok "$(grep 'Packaged' "$work/out.log" | head -1 | sed 's/^ *//')"; else ko "the publish dry run failed"; fi

step "Mutants on a copy of rust/: a session that never moves its send position, and a times count that is never written, are caught"
mkdir -p "$work/src" && cp -R rust "$work/src/rust" && rm -rf "$work/src/rust/target" "$work/src/rust/embedded" && cp -R fixtures "$work/src/fixtures" && cp README.md "$work/src/" && mkdir -p "$work/src/_docs"
caught=0
for m in session unwritten; do
  rm -rf "$work/m" && cp -R "$work/src" "$work/m"
  python3 - "$work/m/rust/src" "$m" <<'PY' || echo "mutation anchor not found: $m" >> "$work/out.log"
import sys
root, m = sys.argv[1], sys.argv[2]
p, a, b = {"session": ("/nostd/session.rs", "self.send_count = self.send_count.wrapping_add(1);", ""),
           "unwritten": ("/nostd/present.rs", "None => rounds || unwritten_count(t, i, row),", "None => rounds,")}[m]
s = open(root + p).read()
assert a in s
open(root + p, "w").write(s.replace(a, b, 1))
PY
  if [ "$m" = session ]; then flags=(--features session --test nostd_session_tests); else flags=(--features text,ecc --test nostd_hostile_pack_tests); fi
  (cd "$work/m/rust" && limit 600 cargo test "${flags[@]}") < /dev/null > "$work/mut-$m.log" 2>&1
  if grep -q 'FAILED' "$work/mut-$m.log"; then caught=$((caught + 1)); else cp "$work/mut-$m.log" "$work/out.log"; fi
done
if [ "$caught" -eq 2 ]; then ok "both mutants fail their tests"; else ko "$caught of 2 mutants caught"; fi

step "Embedded stage: the images base, text, ecc and session link, run under QEMU, have no heap or panic symbol"
if limit 1200 bash rust/embedded/run.sh host < /dev/null > "$work/out.log" 2>&1 && grep -q '=== rust-m4f: PASS' "$work/out.log" && grep -q '=== rust-mutants: PASS' "$work/out.log" && [ "$(grep -c '^SIZE ' "$work/out.log")" -eq 4 ] && ! grep -q 'NOTE FAIL' "$work/out.log"; then
  ok "$(grep '^SIZE ' "$work/out.log" | sed 's/ram=0 B //; s/ raw=.*//' | tr '\n' ';')"
else ko "the Rust embedded stage failed"; fi

step "The script tests of the rust suite and the embedded checks pass"
if (limit 300 bash rust/embedded/checks.test.sh && limit 900 bash .github/workflows/run-suite.test.sh) < /dev/null > "$work/out.log" 2>&1; then ok "checks.test.sh and run-suite.test.sh"; else ko "a script test failed"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
