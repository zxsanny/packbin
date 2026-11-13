#!/usr/bin/env bash
# Loop 120 smoke (AZ-4255, Java refuses a setter that rejects the unpack collection): one paste, PASS/FAIL per step.
# Run from the repository root.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { # the Java suite, CollectionTypeTest included
  limit 600 bash java/test.sh < /dev/null > "$work/java" 2>&1 || { tail -5 "$work/java"; return 1; }
  ! grep -q '^FAIL' "$work/java" && grep -q 'CollectionTypeTest.run' java/src/test/java/packbin/PackbinTest.java && echo "java suite green"
}
s2() { # the two probe lines: pack bytes as before, unpack refused by the package
  limit 400 bash scripts/probes/element-row/run.sh java < /dev/null > "$work/probe" 2> "$work/probe.err" || return 1
  grep "$(printf 'java\tcoll-linkedlist\tbuilt\t')" "$work/probe" | grep -q 'refused: IllegalArgumentException: list: the setter rejected an ArrayList' &&
    grep "$(printf 'java\tcoll-treemap\tbuilt\t')" "$work/probe" | grep -q 'refused: IllegalArgumentException: dict: the setter rejected a LinkedHashMap' &&
    echo "coll-linkedlist and coll-treemap refused at unpack"
}
s3() { # same pack bytes as the ArrayList / HashMap lines of the same shape; no raw exception left
  [ "$(wc -l < "$work/probe" | tr -d ' ')" = 22 ] || return 1
  ! grep -q 'threw:' "$work/probe" &&
    [ "$(grep "$(printf 'java\tcoll-linkedlist\t')" "$work/probe" | cut -f4)" = "$(grep "$(printf 'java\tcoll-arraylist\t')" "$work/probe" | cut -f4)" ] &&
    [ "$(grep "$(printf 'java\tcoll-treemap\t')" "$work/probe" | cut -f4)" = "$(grep "$(printf 'java\tcoll-hashmap\t')" "$work/probe" | cut -f4)" ] &&
    echo "22 lines, no threw:, pack hex of the LinkedList and TreeMap lines equals the ArrayList and HashMap lines"
}
s4() { grep -q 'the setter rejected an ArrayList that unpack creates' README.md && echo "README bullet present"; }
step "1. Java suite green with CollectionTypeTest" s1
step "2. element-row probe: coll-linkedlist and coll-treemap refused at unpack" s2
step "3. 22 probe lines, no raw exception left, pack bytes unchanged" s3
step "4. README Java bullet" s4
if [ "$fail" -eq 0 ]; then echo "smoke 120: 4/4 PASS"; else echo "smoke 120: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
