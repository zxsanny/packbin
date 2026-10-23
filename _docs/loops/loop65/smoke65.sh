#!/usr/bin/env bash
# Loop 65 smoke (CI paths-ignore, Rust size limits, flag-byte chain inside a `times` round: AC-1 to AC-10 of
# _docs/02_task_plans/ci-paths-ignore-size-limits-times-flag-chain/acceptance_criteria.md, then the loop test script).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason.
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

step "AC-1, AC-2: test.yml push ignores exactly _docs/**; the wiring check accepts it and rejects the old file"
if limit 120 bash .github/workflows/ring-wiring.test.sh < /dev/null > "$work/out.log" 2>&1 \
  && grep -q 'rejects: push without the _docs paths-ignore' "$work/out.log" \
  && ruby -ryaml -e 'w = YAML.safe_load(File.read(".github/workflows/test.yml")); on = w["on"] || w[true]; p = on["push"]; exit(p["paths-ignore"] == ["_docs/**"] && p["branches"] == ["**"] && on["pull_request"].nil? && on.key?("workflow_call") ? 0 : 1)'; then
  ok "paths-ignore [_docs/**], branches [**], pull_request and workflow_call unchanged"
else ko "the workflow or its wiring check is off"; fi

step "AC-3: limits.txt holds the owner's rows"
if grep -qx 'base 16384 512' rust/embedded/limits.txt && grep -qx 'text 27964 2898' rust/embedded/limits.txt \
  && grep -qx 'ecc 18879 798' rust/embedded/limits.txt && grep -qx 'session 19325 1924' rust/embedded/limits.txt; then
  ok "base 16384/512, text 27964/2898, ecc 18879/798, session 19325/1924"
else cat rust/embedded/limits.txt > "$work/out.log"; ko "a limit row differs"; fi

step "AC-4: checks.test.sh passes (4 of 4 sets numeric, a dash and a missing line are caught)"
if limit 120 bash rust/embedded/checks.test.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -n 1 "$work/out.log")"; else ko "checks.test.sh failed"; fi

step "AC-5: a text flash limit of 26,631 B fails the Rust embedded stage naming set, figure and limit"
mkdir -p test-results
sed 's/^text .*/text 26631 2898/' rust/embedded/limits.txt > test-results/limits-low.txt
if limit 900 docker compose -f docker-compose.test.yml run --rm -e PACKBIN_RUST_EMBEDDED_LIMITS=/src/test-results/limits-low.txt rust-embedded < /dev/null > "$work/out.log" 2>&1; then
  rm -f test-results/limits-low.txt; ko "the stage passed with a limit one byte under the figure"
else
  rm -f test-results/limits-low.txt
  if grep -q 'text: flash 26632 B over 26631 B' "$work/out.log"; then ok "text: flash 26632 B over 26631 B"; else ko "the stage failed for another reason"; fi
fi

step "AC-7 to AC-9: the arm stage passes: new case 0 failures, deepest stack 612 B of the 2048 B budget and the pin, flash 7,724 B"
if limit 900 docker compose -f docker-compose.test.yml run --rm cpp-embedded < /dev/null > "$work/out.log" 2>&1 \
  && grep -q '^FLAG_ROUND_CHAIN_FAILURES 0' "$work/out.log" && grep -q 'deepest pack/unpack stack 612 B of 2048 (pin 612 B' "$work/out.log" \
  && grep -q 'table 7724 B of 8192 (pin 7724 B)' "$work/out.log" && grep -q 'embedded stage arm: 0 target(s) failed' "$work/out.log"; then
  ok "stack 612 B of 2048 (pin 612), flash 7724 B (pin 7724), 0 targets failed"
else ko "the arm stage failed or a figure moved"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

printf '\n%d/%d steps passed\n' "$passed" "$N"
