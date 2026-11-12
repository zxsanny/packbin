#!/usr/bin/env bash
# Loop 113 smoke (epic AZ-4209, a repeat must be the last thing a packet reads): one paste, PASS/FAIL per step.
# Run from the repository root at the commit before the close commit. The nine package suites, the ring, the ARM
# rows and the publish gate ran in step 11 (scripts/loop-tests.sh --all: 15 of 15, loop record); these are the focused
# checks of the feature.
set -u
fail=0
work="$(mktemp -d)"
probes=scripts/probes/repeat-followed-by-field
tab="$(printf '\t')"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { # the nine probes run from one command and write nothing into the checkout
  git status --porcelain --ignored > "$work/tree-before"
  limit 900 bash "$probes/run.sh" < /dev/null > "$work/run.out" 2> "$work/run.err"; local rc=$?
  git status --porcelain --ignored > "$work/tree-after"
  echo "exit $rc, $(wc -l < "$work/run.out" | tr -d ' ') lines"
  [ "$rc" -eq 0 ] || { tail -5 "$work/run.err"; return 1; }
  [ "$(wc -l < "$work/run.out" | tr -d ' ')" -eq 85 ] || { echo "expected 85 lines"; return 1; }
  cmp -s "$work/tree-before" "$work/tree-after" || { echo "the run changed the tree:"; diff "$work/tree-before" "$work/tree-after"; return 1; }
}
s2() { # every package, and the Rust heap-free API, reads its control scheme back
  local p
  for p in typescript csharp python rust java cpp go swift dart; do
    grep -q -x "$p${tab}control${tab}built${tab}01090506${tab}same" "$work/run.out" || { echo "no control line that reads back: $p"; return 1; }
  done
  grep -q -x "rust${tab}control-nostd${tab}built${tab}01090506${tab}same" "$work/run.out" || { echo "no control line that reads back: rust nostd"; return 1; }
  echo "10 control lines read back"
}
s3() { # the class: every other line is refused when the scheme is built, none builds
  local refused built
  refused="$(awk -F'\t' '$2 !~ /^control/ && $3 ~ /^refused: / {n++} END {print n+0}' "$work/run.out")"
  built="$(awk -F'\t' '$2 !~ /^control/ && $3 == "built" {n++} END {print n+0}' "$work/run.out")"
  echo "refused when built: $refused of 75; still built: $built (a field after a repeat, a second repeat, a repeat in an element, a repeat under when and flags; R5 in Rust in both APIs)"
  [ "$refused" -eq 75 ] && [ "$built" -eq 0 ]
}
s4() { # the rule count: no scheme of the TypeScript suite or of the ring drivers is refused any more
  limit 600 bash "$probes/rule-count/run.sh" < /dev/null > "$work/count.out" 2> "$work/count.err" || { tail -5 "$work/count.err"; return 1; }
  tail -1 "$work/count.out"
  tail -1 "$work/count.out" | grep -q "the rule would refuse 0" && [ "$(grep -c '^refused' "$work/count.out")" -eq 0 ]
}
s5() { # the shared hostile cases: 90 valid, corrupted copies fail (the loaders replay them in step 11)
  limit 900 bash fixtures/hostile/check-cases.sh < /dev/null | tail -1 | grep -q '^hostile cases ok: 90$' || { echo "not 90 cases"; return 1; }
  limit 900 bash fixtures/hostile/cases.test.sh < /dev/null | tail -1
  for c in construct_repeat_in_group_in_repeat_round construct_repeat_in_group_in_times_round pack_times_then_field; do
    grep -q "^$c " fixtures/hostile/cases.txt || { echo "missing case $c"; return 1; }
  done
}
s6() { # the probe scripts parse and pass shellcheck
  local f n
  command -v shellcheck > /dev/null || { echo "shellcheck is not installed"; return 1; }
  for f in "$probes/run.sh" "$probes"/*/run.sh; do bash -n "$f" || return 1; done
  shellcheck "$probes/run.sh" "$probes"/*/run.sh && n="$(ls "$probes/run.sh" "$probes"/*/run.sh | wc -l | tr -d ' ')" && echo "$n scripts clean"
}
s7() { # the epic's specs are done, the contract says implemented, the follow-ups are queued
  local n f
  for n in 10 11 12 13 14 15 16 17 18 19 32; do
    f="$(ls _docs/02_tasks/done/AZ-42"$n"_*.md 2> /dev/null)" || { echo "no done spec for AZ-42$n"; return 1; }
    ! ls _docs/02_tasks/todo/AZ-42"$n"_*.md > /dev/null 2>&1 || { echo "AZ-42$n is still in todo/"; return 1; }
    grep -q "^\*\*Epic\*\*: AZ-4209$" "$f" || { echo "epic line missing: AZ-42$n"; return 1; }
  done
  grep -q '^\*\*Version\*\*: 1.0.2$' _docs/02_document/contracts/library/repeat-last.md \
    && grep -q 'implemented in all nine packages in loop 113' _docs/02_document/contracts/library/repeat-last.md \
    && grep -q 'A `repeat` must be the last thing a packet reads' README.md \
    && test -f _docs/02_tasks/backlog/csharp-flags-in-flags-presence.md \
    && test -f _docs/02_tasks/backlog/esp-core-arduino-pin.md \
    && test -f _docs/OPERATOR_TODO.md \
    && echo "11 specs in done/, contract 1.0.2 implemented, README rule, queue items and operator to-do present"
}
s8() { # no code changed since the total run of step 11 (888a3e8): only documents
  local bad
  bad="$( { git diff --name-only 888a3e8; git ls-files --others --exclude-standard; } | sort -u | grep -vE '^_docs/' || true)"
  [ -z "$bad" ] || { echo "$bad"; return 1; }
  echo "$( { git diff --name-only 888a3e8; git ls-files --others --exclude-standard; } | sort -u | wc -l | tr -d ' ') paths since 888a3e8, all under _docs/"
}
step "1 nine probes run from one command, 85 lines, tree unchanged" s1
step "2 every control scheme reads back" s2
step "3 the class is refused when the scheme is built, in all nine packages" s3
step "4 rule count: 0 schemes of the TypeScript suite and the ring drivers refused" s4
step "5 the 90 shared hostile cases are valid" s5
step "6 probe scripts parse and pass shellcheck" s6
step "7 specs done, contract implemented, README, queue and operator to-do" s7
step "8 no code changed since the step 11 run" s8
[ "$fail" -eq 0 ] && echo "SMOKE 113: ALL PASS (8/8)" || echo "SMOKE 113: FAILED (step logs kept in $work)"
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
