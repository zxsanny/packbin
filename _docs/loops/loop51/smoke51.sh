#!/usr/bin/env bash
# Loop 51 smoke (Rust heap-free API, nested kinds; AZ-2752, AZ-2753). One line per step: [n/N] title, then PASS (Ns)
# <result> or FAIL with the reason. No network (the libraries and the image are built from what is on disk).
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

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "The crate builds as no_std with default features off and the flat heap-free tests pass"
if (cd rust && limit 600 cargo build --no-default-features && limit 600 cargo test --no-default-features --test nostd_flat_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 12 passed' "$work/out.log"; then ok "no_std build; $(result_of "$work/out.log")"; else ko "no_std build or tests failed"; fi

step "The default Rust suite passes"
if (cd rust && limit 900 cargo test) < /dev/null > "$work/out.log" 2>&1 && [ "$(result_of "$work/out.log" | awk '{print $3}')" = "0" ]; then
  ok "$(result_of "$work/out.log") in $(grep -c '^test result' "$work/out.log") targets"
else ko "the default suite failed"; fi

step "AZ-2752 AC-1..AC-4: flags, flag bytes, bits, u2, packed, sized and when pack and read as std does"
if (cd rust && limit 600 cargo test --test nostd_bits_when_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 11 passed' "$work/out.log"; then ok "$(result_of "$work/out.log") (13 layouts, refusals, presence matrix, storage)"; else ko "the AZ-2752 tests failed"; fi

step "AZ-2753 AC-1, AC-2, AC-4: repeat, group, times and lists pack and read as std does; limits; the route example"
if (cd rust && limit 600 cargo test --test nostd_rounds_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 12 passed' "$work/out.log"; then ok "$(result_of "$work/out.log") (16 layouts, rounds and slots limits, storage, hostile counts)"; else ko "the AZ-2753 tests failed"; fi

step "Mutants on a copy of rust/: a repeat on for empty rounds, and a when that ignores a skipped source, are caught"
mkdir -p "$work/src/fixtures" && cp -R rust "$work/src/rust" && rm -rf "$work/src/rust/target" "$work/src/rust/embedded" && cp fixtures/golden.hex "$work/src/fixtures/"
caught=0
for m in repeat when; do
  rm -rf "$work/m" && cp -R "$work/src" "$work/m"
  python3 - "$work/m/rust/src/nostd/present.rs" "$m" <<'PY' || echo "mutation anchor not found: $m" >> "$work/out.log"
import sys
p, m = sys.argv[1], sys.argv[2]; s = open(p).read()
a, b = {"repeat": ("Kind::Repeat => repeat_present(t, i, f, row, skip_late),", "Kind::Repeat => row.count(f.id).is_some_and(|n| n != 0),"),
        "when": ("(!skipped).then_some(value)", "Some(value)")}[m]
assert a in s
open(p, "w").write(s.replace(a, b))
PY
  test_file=$([ "$m" = repeat ] && echo nostd_rounds_tests || echo nostd_bits_when_tests)
  (cd "$work/m/rust" && limit 600 cargo test --test "$test_file") < /dev/null > "$work/mut-$m.log" 2>&1
  if grep -q 'FAILED' "$work/mut-$m.log"; then caught=$((caught + 1)); else cp "$work/mut-$m.log" "$work/out.log"; fi
done
if [ "$caught" -eq 2 ]; then ok "both mutants fail their tests"; else ko "$caught of 2 mutants caught"; fi

step "AZ-2751 stage: the Cortex-M4F image links, decodes the golden fixture under QEMU, has no heap or panic symbol"
if limit 900 bash rust/embedded/run.sh host < /dev/null > "$work/out.log" 2>&1 && grep -q '=== rust-m4f: PASS' "$work/out.log" && grep -q '=== rust-mutants: PASS' "$work/out.log" && grep -q '^GOLDEN_OK 1' "$work/out.log"; then
  ok "$(grep '^SIZE' "$work/out.log" | head -1)"
  sizes="$(grep '^SIZE base' "$work/out.log" | head -1)"
else ko "the Rust embedded stage failed"; sizes=""; fi

step "The owner's base limit (16,384 B) is in force: a limit one byte below each figure fails and names it"
flash="$(printf '%s' "$sizes" | sed -n 's/.*flash=\([0-9]*\) B.*/\1/p')"
stack="$(printf '%s' "$sizes" | sed -n 's/.*stack=\([0-9]*\) B.*/\1/p')"
if [ -z "$flash" ] || [ -z "$stack" ]; then ko "no sizes from the previous step"
else
  printf 'base %s %s\n' "$((flash - 1))" "$((stack - 1))" > rust/embedded/build/smoke-limits.txt
  if limit 600 docker compose -f docker-compose.test.yml run --rm -e PACKBIN_RUST_EMBEDDED_LIMITS=/src/rust/embedded/build/smoke-limits.txt rust-embedded < /dev/null > "$work/out.log" 2>&1; then
    ko "the stage passed with a limit below the size"
  elif grep -q "FAIL base: flash $flash B over $((flash - 1)) B" "$work/out.log" && grep -q "FAIL base: stack $stack B over $((stack - 1)) B" "$work/out.log" && grep -q '^base 16384 512' rust/embedded/limits.txt; then
    ok "fails with: flash $flash B over $((flash - 1)) B; stack $stack B over $((stack - 1)) B; limits.txt has base 16384 512"
  else ko "failed without naming the figure, or limits.txt is not 16384 512"; fi
fi

step "Guards: the link-check self-test, the job, parts and loop-tests guards pass"
if { bash rust/embedded/checks.test.sh && bash .github/workflows/publish-jobs.test.sh && bash cpp/embedded/run-parts.test.sh && bash scripts/loop-tests.test.sh; } < /dev/null > "$work/out.log" 2>&1; then ok "checks.test.sh, publish-jobs.test.sh, run-parts.test.sh, loop-tests.test.sh"; else ko "a guard test failed"; fi

printf '\nRESULT %d of %d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
