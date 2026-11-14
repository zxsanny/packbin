#!/usr/bin/env bash
# Loop 125 smoke (scheme depth probe, AZ-4291): one paste, PASS/FAIL per step. Run from the repository root with a
# clean tree, after step 11. The full nine-package run (60 lines, 303 s) was done once at the loop's findings; this
# script re-runs the six fast packages twice for the repeatability check.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
probe=scripts/probes/scheme-depth
batch="$(git log -1 --format=%H --grep='Probe scheme depth in all nine packages')"
s1() { # clean tree; step 11 scaffold stamp at the batch commit or later
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  git merge-base --is-ancestor "$batch" "$(cat test-results/stamps/scaffold)" || { echo "scaffold stamp older than ${batch:0:7}"; return 1; }
  echo "application tree clean; scaffold stamp at or after ${batch:0:7}"
}
s2() { # AC-5: no package source changed since before the loop
  local n; n="$(git diff --name-only 553812a HEAD -- typescript java go swift rust python cpp csharp dart | wc -l | tr -d ' ')"
  [ "$n" -eq 0 ] && echo "0 package files changed"
}
s3() { # AC-1, AC-2, AC-4: six packages, six lines each, twice, same lines; nothing written
  local a b
  a="$(limit 300 bash $probe/run.sh typescript python cpp dart csharp java </dev/null 2>/dev/null | awk -F'\t' '!($1=="java" && $2=="group-5000")')" || return 1
  b="$(limit 300 bash $probe/run.sh typescript python cpp dart csharp java </dev/null 2>/dev/null | awk -F'\t' '!($1=="java" && $2=="group-5000")')" || return 1
  [ "$(printf '%s\n' "$a" | wc -l | tr -d ' ')" -eq 35 ] || { echo "expected 35 lines"; printf '%s\n' "$a" | wc -l; return 1; }
  [ "$a" = "$b" ] || { echo "two runs differ"; diff <(printf '%s\n' "$a") <(printf '%s\n' "$b"); return 1; }
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  echo "35 lines twice, identical (java group-5000 excluded: edge of the limit), no file written"
}
s4() { # AC-3: findings table has a row per package, shape and depth (60 plus the 6 nostd rows)
  local f=_docs/06_metrics/scheme-depth-probe_2026-11-14.md n p
  n="$(grep -c '^| [a-z]* | \(when\|group\)' $f | tr -d ' ')"
  [ "$n" -eq 60 ] || { echo "$n table rows, expected 60"; return 1; }
  for p in typescript java go swift rust python cpp csharp dart; do grep -q "^| $p |" $f || { echo "no row for $p"; return 1; }; done
  echo "60 rows, nine packages"
}
s5() { shellcheck -S warning $probe/run.sh $probe/case.sh $probe/*/run.sh && bash -n $probe/run.sh && echo "lint clean"; }
s6() { # AC-2: a dying case is one line and the next case still runs
  local o
  o="$(bash $probe/case.sh x s1 5 bash -c 'kill -SEGV $$'; bash $probe/case.sh x s2 1 sleep 5; bash $probe/case.sh x s3 5 bash -c 'exit 3')"
  printf '%s\n' "$o"
  [ "$(printf '%s\n' "$o" | grep -c 'crashed: ')" -eq 3 ]
}
step "1. application tree clean; step 11 scaffold stamp at the batch commit or later" s1
step "2. no package source changed (AC-5)" s2
step "3. six fast packages twice: 35 lines, identical, nothing written (AC-1, AC-4)" s3
step "4. findings table: 60 rows, nine packages (AC-3)" s4
step "5. shellcheck and bash -n clean" s5
step "6. a crash, a timeout and an exit are lines (AC-2)" s6
if [ "$fail" -eq 0 ]; then echo "smoke 125: 6/6 PASS"; else echo "smoke 125: FAIL (see above)"; fi
exit "$fail"
