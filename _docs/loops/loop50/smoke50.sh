#!/usr/bin/env bash
# Loop 50 smoke (Rust heap-free API; AZ-2749, AZ-2751). One line per step: [n/N] title, then PASS (Ns) <result> or FAIL
# with the reason. No network (the static libraries and the image are built from what is on disk).
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f "$repo/rust/embedded/build/smoke-limits.txt"' EXIT
N=7 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "AZ-2749 AC-1: the crate builds as no_std with default features off, and the heap-free tests pass"
if (cd rust && limit 600 cargo build --no-default-features && limit 600 cargo test --no-default-features --test nostd_flat_tests) < /dev/null > "$work/out.log" 2>&1 && grep -q 'test result: ok. 12 passed' "$work/out.log"; then ok "no_std build; $(grep 'test result' "$work/out.log" | tail -1 | cut -c1-60)"; else ko "no_std build or tests failed"; fi

step "AZ-2749 AC-2/AC-7: std and nostd write the same bytes (differential tests) and the default suite passes"
if (cd rust && limit 900 cargo test) < /dev/null > "$work/out.log" 2>&1 && ! grep -q 'FAILED\|failed;' "$work/out.log" | grep -v ' 0 failed'; then
  ok "$(grep '^test result' "$work/out.log" | awk '{p+=$4; f+=$6} END {print p " passed, " f " failed in " NR " targets"}')"
else ko "the default suite failed"; fi

step "AZ-2749 AC-6: with the big-endian copy broken the differential test fails (copy of rust/, repo untouched)"
mkdir -p "$work/src" && cp -R rust "$work/src/rust" && rm -rf "$work/src/rust/target" "$work/src/rust/embedded" && mkdir -p "$work/src/fixtures" && cp fixtures/golden.hex "$work/src/fixtures/"
python3 - "$work/src/rust/src/nostd/walk.rs" <<'PY' || echo "mutation anchor not found" > "$work/out.log"
import sys
p = sys.argv[1]; s = open(p).read()
a = "low.iter().rev()"
assert a in s
open(p, "w").write(s.replace(a, "low.iter()"))
PY
if [ ! -f "$work/out.log" ]; then
  (cd "$work/src/rust" && limit 600 cargo test --test nostd_differential_tests --test nostd_flat_tests) < /dev/null > "$work/mut.log" 2>&1
  if grep -q 'FAILED' "$work/mut.log"; then ok "the mutant is caught ($(grep -c 'FAILED' "$work/mut.log") failing test lines)"; else cp "$work/mut.log" "$work/out.log"; ko "the mutant was not caught"; fi
else ko "could not build the mutant"; fi

step "AZ-2751 AC-1/2/4/5: the Cortex-M4F image links, decodes the golden fixture on QEMU, has no heap or panic symbol; sizes printed"
if limit 900 bash rust/embedded/run.sh host < /dev/null > "$work/out.log" 2>&1 && grep -q '=== rust-m4f: PASS' "$work/out.log" && grep -q '=== rust-mutants: PASS' "$work/out.log" && grep -q '^GOLDEN_OK 1' "$work/out.log"; then
  ok "$(grep '^SIZE' "$work/out.log" | head -1)"
else ko "the Rust embedded stage failed"; fi

step "AZ-2751 AC-3: a limit lowered by one byte fails the stage and names the figure"
printf 'base 2651 87\n' > rust/embedded/build/smoke-limits.txt
if limit 600 docker compose -f docker-compose.test.yml run --rm -e PACKBIN_RUST_EMBEDDED_LIMITS=/src/rust/embedded/build/smoke-limits.txt rust-embedded < /dev/null > "$work/out.log" 2>&1; then
  ko "the stage passed with a limit below the size"
elif grep -q 'FAIL base: flash 2652 B over 2651 B' "$work/out.log" && grep -q 'FAIL base: stack 88 B over 87 B' "$work/out.log"; then
  ok "fails with: flash 2652 B over 2651 B; stack 88 B over 87 B"
else ko "failed without naming the figure"; fi

step "AZ-2751 AC-4/5: the link-check self-test passes and the stage guards (jobs, parts, loop-tests) still pass"
if { bash rust/embedded/checks.test.sh && bash .github/workflows/publish-jobs.test.sh && bash cpp/embedded/run-parts.test.sh && bash scripts/loop-tests.test.sh; } < /dev/null > "$work/out.log" 2>&1; then ok "checks.test.sh, publish-jobs.test.sh, run-parts.test.sh, loop-tests.test.sh"; else ko "a guard test failed"; fi

printf '\nRESULT %d of %d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
