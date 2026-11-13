#!/usr/bin/env bash
# Loop 117 smoke (AZ-4243, a dirty _docs/ does not block a loop-tests stage stamp): one paste, PASS/FAIL per step.
# Run from the repository root after step 11 of loop 117 (it reads the stamp that run wrote).
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { limit 300 bash scripts/loop-tests.test.sh < /dev/null; }
s2() { shellcheck scripts/loop-tests.sh scripts/loop-tests.test.sh && echo "shellcheck clean"; }
s3() { # step 11 of this loop ran with _docs/ dirty and still wrote the scaffold stamp at its commit
  local want stamp
  want="$(git log -1 --format=%H --grep='A dirty _docs/ does not block a loop-tests stage stamp')"
  stamp="$(cat test-results/stamps/scaffold)"
  [ -n "$want" ] && git merge-base --is-ancestor "$want" "$stamp" && echo "scaffold stamp ${stamp:0:7}, at or after ${want:0:7}"
}
s4() { # the plan skips scaffold now, while _docs/ holds this loop's uncommitted files
  bash scripts/loop-tests.sh --plan --only scaffold < /dev/null | tee "$work/plan" | grep -q '^PLAN scaffold SKIP (unchanged since' &&
    grep '^PLAN scaffold' "$work/plan"
}
s5() { grep -q 'clean apart from `_docs/`' _docs/04_deploy/deployment_procedures.md && echo "procedure text updated"; }
step "1. scripts/loop-tests.test.sh passes" s1
step "2. shellcheck clean on both scripts" s2
step "3. step 11 wrote the scaffold stamp with _docs/ dirty" s3
step "4. --plan skips scaffold as unchanged" s4
step "5. deployment_procedures.md says a stamp ignores _docs/" s5
if [ "$fail" -eq 0 ]; then echo "smoke 117: 5/5 PASS"; else echo "smoke 117: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
