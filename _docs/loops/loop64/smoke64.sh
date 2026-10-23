#!/usr/bin/env bash
# Loop 64 smoke (retrospective of loops 61 to 63: a documents-only loop; AC-1 to AC-6 of
# _docs/02_task_plans/retro-loops-61-63/acceptance_criteria.md, then the loop test script).
# One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=7 n=0 passed=0
retro=_docs/06_metrics/retro_2026-10-23_loop64.md

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "AC-5: every path changed since the end of loop 63 (3619a2d), committed or not, is under _docs/"
{ git diff --name-only 3619a2d; git ls-files --others --exclude-standard; } | sort -u | grep -v '^_docs/' > "$work/out.log" || true
if [ ! -s "$work/out.log" ]; then ok "$({ git diff --name-only 3619a2d; git ls-files --others --exclude-standard; } | sort -u | wc -l | tr -d ' ') paths, all under _docs/"
else ko "paths outside _docs/"; fi

step "AC-1: the report has its three sections, a row for each of loops 61, 62 and 63, and names the loop 60 retro"
if [ -f "$retro" ] && grep -q '^## Metrics' "$retro" && grep -q '^## What the data says' "$retro" && grep -q '^## Improvements' "$retro" \
  && grep -q '^| 61 |' "$retro" && grep -q '^| 62 |' "$retro" && grep -q '^| 63 |' "$retro" && grep -q 'retro_2026-10-22_loop60.md' "$retro"; then
  ok "$retro, $(wc -l < "$retro" | tr -d ' ') lines"
else ko "the report or one of its parts is missing"; fi

step "AC-2: commits (2, 4, 5), points (8) and flash figures in the report equal git and the specs"
c61=$(git rev-list --count 603fbf4^..8963422); c62=$(git rev-list --count 1ef7690^..c9ceaa7); c63=$(git rev-list --count 0172a1c^..3619a2d)
pts=0; for f in AZ-PENDING_cpp_pack_held_of_measure AZ-PENDING_cpp_field_layout_shrink AZ-PENDING_cpp_pack_flash_saving; do
  p=$(grep -o '^\*\*Complexity\*\*: [0-9]*' "_docs/02_tasks/done/$f.md" | grep -o '[0-9]*$'); pts=$((pts + p)); done
if [ "$c61 $c62 $c63 $pts" = "2 4 5 8" ] && grep -q '^| 61 |.*| 1 / 2 | 2 |' "$retro" && grep -q '^| 62 |.*| 1 / 3 | 4 |' "$retro" && grep -q '^| 63 |.*| 1 / 3 | 5 |' "$retro" \
  && grep -q '3 tasks, 8 points, 11 commits' "$retro" && grep -q '8,032 B to 7,724 B' "$retro" && grep -q '504 B to 496 B' "$retro"; then
  ok "commits $c61 / $c62 / $c63, $pts points, flash 8,032 B to 7,724 B, stack 504 B to 496 B"
else printf 'git %s %s %s, points %s\n' "$c61" "$c62" "$c63" "$pts" > "$work/out.log"; ko "a figure of the report differs from git or the specs"; fi

step "AC-3: LESSONS.md holds at most 15 entries, 1 to 3 of them from this retro, each followed by a Source line; the gotcha line is in"
e=$(grep -c '^- \[' _docs/LESSONS.md); s=$(grep -c '^  Source: _docs/06_metrics/retro_2026-10-23_loop64.md' _docs/LESSONS.md); sa=$(grep -c '^  Source:' _docs/LESSONS.md)
if [ "$e" -le 15 ] && [ "$s" -ge 1 ] && [ "$s" -le 3 ] && [ "$e" = "$sa" ] && grep -q '^- Every figure an AC or an estimate names' _docs/AGENT_GOTCHAS.md; then
  ok "$e entries, $s new, $e Source lines, gotcha line present"
else printf 'entries %s, new %s, sources %s\n' "$e" "$s" "$sa" > "$work/out.log"; ko "LESSONS.md or AGENT_GOTCHAS.md is off"; fi

step "AC-4: exactly 3 numbered improvements, each with a file, a command or a rule to apply"
imp=$(awk '/^## Improvements/{f=1;next} f&&/^[0-9]+\. /{c++} END{print c+0}' "$retro")
if [ "$imp" = 3 ]; then ok "3 improvements"; else printf 'improvements: %s\n' "$imp" > "$work/out.log"; ko "expected 3 improvements"; fi

step "AC-6: both Jira leftovers keep their payload and no new AZ-PENDING task spec appeared"
before=$(git ls-tree -r --name-only 3619a2d _docs/02_tasks | grep -c 'AZ-PENDING' || true); after=$(find _docs/02_tasks -name 'AZ-PENDING*' | wc -l | tr -d ' ')
if grep -q 'transitionJiraIssue AZ-3163' _docs/_process_leftovers/2026-10-22_loop59_jira_in_testing.md && grep -q 'transitionJiraIssue AZ-3164' _docs/_process_leftovers/2026-10-22_loop59_jira_in_testing.md \
  && grep -q 'cpp_pack_flash_saving' _docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md && [ "$before" = "$after" ]; then
  ok "both leftovers intact; $after AZ-PENDING specs, as at 3619a2d"
else printf 'AZ-PENDING specs: before %s, after %s\n' "$before" "$after" > "$work/out.log"; ko "a leftover changed or a spec was added"; fi

step "The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)"
if limit 2400 bash scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1 && grep -q '^RESULT' "$work/out.log"; then
  ok "$(grep '^RESULT' "$work/out.log")"
else ko "scripts/loop-tests.sh failed"; fi

printf '\n%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
