#!/usr/bin/env bash
# Loop 124 smoke (run-suite split, AZ-4288): one paste, PASS/FAIL per step. Run from the repository root with a clean
# application tree, after step 11 (it reads the stage stamps). Needs python3.13 with PyYAML for the self-tests.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
wf=.github/workflows
batch="$(git log -1 --format=%H --grep='Split run-suite.sh: Go, Rust and C++ helpers')"
mkdir -p "$work/py" && ln -sf /opt/homebrew/bin/python3.13 "$work/py/python3"
PATH="$work/py:$PATH"
s1() { # clean application tree; step 11 passed every suite stage at the batch commit or later
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  local stage stamp
  for stage in go typescript csharp python rust java cpp swift dart scaffold publish-gate; do
    stamp="$(cat "test-results/stamps/$stage")" || return 1
    git merge-base --is-ancestor "$batch" "$stamp" || { echo "stamp $stage is older than ${batch:0:7}"; return 1; }
  done
  echo "11 stage stamps at or after ${batch:0:7}"
}
s2() { # sizes: run-suite.sh under 400, run-suite.test.sh at most 500
  local a b; a="$(wc -l < $wf/run-suite.sh | tr -d ' ')"; b="$(wc -l < $wf/run-suite.test.sh | tr -d ' ')"
  [ "$a" -lt 400 ] && [ "$b" -le 500 ] && echo "run-suite.sh $a lines, run-suite.test.sh $b lines"
}
s3() { # the removed lines and the moved lines are the same, word for word
  git diff -U0 "$batch^" "$batch" -- $wf/run-suite.sh | grep '^-' | grep -v '^---' | sed 's/^-//' | grep -v '^$' > "$work/removed"
  git show "$batch:$wf/run-suite-cpp.sh" "$batch:$wf/run-suite-go.sh" "$batch:$wf/run-suite-rust.sh" |
    sed '/^#!\/usr\/bin\/env bash$/d;/^# The .* helpers of run-suite.sh (AZ-4288)/d;/^# as run-suite-dart.sh is/d;/^# shellcheck disable=SC2154$/d' | grep -v '^$' > "$work/moved"
  diff "$work/removed" "$work/moved" && echo "$(wc -l < "$work/removed" | tr -d ' ') lines moved unchanged"
}
s4() { # the self-tests pass
  limit 600 bash $wf/run-suite.test.sh < /dev/null > "$work/rs" 2>&1 || { tail -5 "$work/rs"; return 1; }
  limit 300 bash $wf/report-row.test.sh < /dev/null > "$work/rr" 2>&1 || { tail -5 "$work/rr"; return 1; }
  tail -1 "$work/rs"; tail -1 "$work/rr"
}
s5() { # a copy without one helper file fails the self-test (copies skip the file; nothing is deleted)
  local lang dir n
  for lang in cpp go rust; do
    dir="$work/mut-$lang"; mkdir -p "$dir"
    for f in $wf/*.sh $wf/tool-pins.txt; do [ "$(basename "$f")" = "run-suite-$lang.sh" ] || cp "$f" "$dir/"; done
    n="$(RUN_SUITE_SH="$dir/run-suite.sh" limit 600 bash $wf/run-suite.test.sh < /dev/null 2>&1 | grep -c '^FAIL')"
    [ "$n" -gt 0 ] || { echo "without run-suite-$lang.sh the self-test passed"; return 1; }
    printf 'without run-suite-%s.sh: %s failures\n' "$lang" "$n"
  done
}
s6() { shellcheck -S warning $wf/run-suite.sh $wf/run-suite-*.sh $wf/report-row.test.sh && echo "lint clean"; }
step "1. tree is the batch commit; step 11 stamps (11 stages) at it or later" s1
step "2. run-suite.sh under 400 lines, run-suite.test.sh within 500" s2
step "3. the moved helpers are word for word the removed lines" s3
step "4. run-suite.test.sh and report-row.test.sh pass" s4
step "5. a copy without run-suite-cpp/go/rust.sh fails the self-test" s5
step "6. shellcheck -S warning clean" s6
if [ "$fail" -eq 0 ]; then echo "smoke 124: 6/6 PASS"; else echo "smoke 124: FAIL (see above)"; fi
exit "$fail"
