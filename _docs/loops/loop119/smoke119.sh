#!/usr/bin/env bash
# Loop 119 smoke (AZ-4253, Java refuses a member of another row class at build): one paste, PASS/FAIL per step.
# Run from the repository root.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { # the Java suite, RowClassTest included
  limit 600 bash java/test.sh < /dev/null > "$work/java" 2>&1 || { tail -5 "$work/java"; return 1; }
  ! grep -q '^FAIL' "$work/java" && grep -q 'RowClassTest\|AZ-4253' java/src/test/java/packbin/PackbinTest.java && echo "java suite green"
}
s2() { # the two probe lines are refused by the package, naming the member and the row class
  limit 400 bash scripts/probes/element-row/run.sh java < /dev/null > "$work/probe" 2> "$work/probe.err" || return 1
  for shape in other-row nested-other-row; do
    grep -q "$(printf 'java\t%s\trefused: IllegalArgumentException: utf8 0: declared for another row class; this row is Comment' "$shape")" "$work/probe" || return 1
  done
  echo "other-row and nested-other-row refused at build"
}
s3() { # nothing else in the Java probe moved: 22 lines; the only raw exceptions left are the two of D12
  [ "$(wc -l < "$work/probe" | tr -d ' ')" = 22 ] || return 1
  [ "$(grep -c 'threw:' "$work/probe")" = 2 ] && grep 'threw:' "$work/probe" | grep -q 'coll-linkedlist' &&
    grep 'threw:' "$work/probe" | grep -q 'coll-treemap' && echo "22 lines; threw: only coll-linkedlist and coll-treemap (D12)"
}
s4() { grep -q 'declared for another row class; this row is Child' README.md && echo "README bullet present"; }
s5() { grep -q '^| D13 |.*| applied 2026-11-13 |$' _docs/OPERATOR_TODO.md && echo "D13 recorded as applied"; }
step "1. Java suite green with RowClassTest" s1
step "2. element-row probe: other-row and nested-other-row refused" s2
step "3. no other Java probe line changed" s3
step "4. README Java bullet" s4
step "5. mechanism decision D13 recorded" s5
if [ "$fail" -eq 0 ]; then echo "smoke 119: 5/5 PASS"; else echo "smoke 119: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
