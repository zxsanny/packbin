#!/usr/bin/env bash
# Loop 52 smoke (Rust heap-free API, text, dictionaries and ECC; AZ-2754, AZ-2755). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network (the libraries and the image are built from disk).
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

step "The crate builds as no_std with and without text and ecc, and the flat heap-free tests pass"
if (cd rust && limit 600 cargo build --no-default-features && limit 600 cargo build --no-default-features --features text,ecc && limit 600 cargo test --no-default-features --test nostd_flat_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 12 passed' "$work/out.log"; then ok "three builds; $(result_of "$work/out.log")"; else ko "a no_std build or the flat tests failed"; fi

step "The default Rust suite passes (features off: the two off tests run inside)"
if (cd rust && limit 900 cargo test) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then
  ok "$(result_of "$work/out.log") in $(grep -c '^test result' "$work/out.log") targets"
else ko "the default suite failed"; fi

step "AZ-2754 AC-1..AC-5: strings and dictionaries pack and read as std does; vectors; scratch; hostile dictionaries; text off"
if (cd rust && limit 900 cargo test --features text --test nostd_text_tests --test nostd_dict_tests --test nostd_text_differential_tests && limit 300 cargo test --test nostd_text_off_tests) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then ok "$(result_of "$work/out.log") (20 layouts, 427 vector rows, six hostile dictionary packets)"; else ko "the AZ-2754 tests failed"; fi

step "AZ-2755 AC-1..AC-4: parity, repair in place, 254-byte limit, 1,339 vector rows, std differential; ecc off"
if (cd rust && limit 600 cargo test --features ecc --test nostd_ecc_tests && limit 300 cargo test --test nostd_ecc_off_tests) < /dev/null > "$work/out.log" 2>&1 && clean_result "$work/out.log"; then ok "$(result_of "$work/out.log")"; else ko "the AZ-2755 tests failed"; fi

step "Mutants on a copy of rust/: a dictionary that accepts a repeated key, and a repair that ignores the limit, are caught"
mkdir -p "$work/src/fixtures" && cp -R rust "$work/src/rust" && rm -rf "$work/src/rust/target" "$work/src/rust/embedded" && cp fixtures/golden.hex "$work/src/fixtures/" && cp -R fixtures/ecc fixtures/text fixtures/hostile "$work/src/fixtures/"
caught=0
for m in dict ecc; do
  rm -rf "$work/m" && cp -R "$work/src" "$work/m"
  python3 - "$work/m/rust/src" "$m" <<'PY' || echo "mutation anchor not found: $m" >> "$work/out.log"
import sys
root, m = sys.argv[1], sys.argv[2]
p, a, b = {"dict": ("/nostd/strings.rs", "compare_payloads(a, b) == Ordering::Less", "compare_payloads(a, b) != Ordering::Greater"),
           "ecc": ("/ecc_core.rs", "if deg == 0 || deg > t {", "if deg == 0 {")}[m]
s = open(root + p).read()
assert a in s
open(root + p, "w").write(s.replace(a, b))
PY
  if [ "$m" = dict ]; then flags=(--features text --test nostd_dict_tests); else flags=(--features ecc --test nostd_ecc_tests); fi
  (cd "$work/m/rust" && limit 600 cargo test "${flags[@]}") < /dev/null > "$work/mut-$m.log" 2>&1
  if grep -q 'FAILED' "$work/mut-$m.log"; then caught=$((caught + 1)); else cp "$work/mut-$m.log" "$work/out.log"; fi
done
if [ "$caught" -eq 2 ]; then ok "both mutants fail their tests"; else ko "$caught of 2 mutants caught"; fi

step "Embedded stage: the images base, text and ecc link, run under QEMU, have no heap or panic symbol"
if limit 900 bash rust/embedded/run.sh host < /dev/null > "$work/out.log" 2>&1 && grep -q '=== rust-m4f: PASS' "$work/out.log" && grep -q '=== rust-mutants: PASS' "$work/out.log" && [ "$(grep -c '^SIZE ' "$work/out.log")" -eq 3 ]; then
  ok "$(grep '^SIZE ' "$work/out.log" | sed 's/ram=0 B //' | tr '\n' ';')"
  sizes="$(grep '^SIZE base' "$work/out.log" | head -1)"
else ko "the Rust embedded stage failed"; sizes=""; fi

step "The owner's base limit (16,384 B) is in force: a limit one byte below each figure fails and names it"
flash="$(printf '%s' "$sizes" | sed -n 's/.*flash=\([0-9]*\) B.*/\1/p')"
stack="$(printf '%s' "$sizes" | sed -n 's/.*stack=\([0-9]*\) B.*/\1/p')"
if [ -z "$flash" ] || [ -z "$stack" ]; then ko "no sizes from the previous step"
else
  printf 'base %s %s\ntext - -\necc - -\n' "$((flash - 1))" "$((stack - 1))" > rust/embedded/build/smoke-limits.txt
  if limit 600 docker compose -f docker-compose.test.yml run --rm -e PACKBIN_RUST_EMBEDDED_LIMITS=/src/rust/embedded/build/smoke-limits.txt rust-embedded < /dev/null > "$work/out.log" 2>&1; then
    ko "the stage passed with a limit below the size"
  elif grep -q "FAIL base: flash $flash B over $((flash - 1)) B" "$work/out.log" && grep -q "FAIL base: stack $stack B over $((stack - 1)) B" "$work/out.log" && grep -q '^base 16384 512' rust/embedded/limits.txt; then
    ok "fails with: flash $flash B over $((flash - 1)) B; stack $stack B over $((stack - 1)) B; limits.txt has base 16384 512"
  else ko "failed without naming the figure, or limits.txt is not 16384 512"; fi
fi

step "Guards: the link-check self-test, the job, parts, loop-tests and run-suite guards pass"
if { bash rust/embedded/checks.test.sh && bash .github/workflows/publish-jobs.test.sh && bash cpp/embedded/run-parts.test.sh && bash scripts/loop-tests.test.sh && bash .github/workflows/run-suite.test.sh; } < /dev/null > "$work/out.log" 2>&1; then ok "checks.test.sh, publish-jobs.test.sh, run-parts.test.sh, loop-tests.test.sh, run-suite.test.sh"; else ko "a guard test failed"; fi

printf '\nRESULT %d of %d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
