#!/usr/bin/env bash
# Loop 121 smoke (hygiene: AZ-4257 to AZ-4261): one paste, PASS/FAIL per step. Run from the repository root after step 11
# (it reads the stage stamps that run wrote). Python 3.13 on PATH as python3.13, or PACKBIN_PROBE_PYTHON set.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
batch="$(git log -1 --format=%H --grep='Hygiene: eight small agent-found fixes')"
s1() { # step 11 passed these stages at the batch commit or later
  local stage stamp
  for stage in go csharp java python dart cpp cpp-embedded-arm scaffold ring publish-gate; do
    stamp="$(cat "test-results/stamps/$stage" 2>/dev/null)" || { echo "no stamp for $stage"; return 1; }
    git merge-base --is-ancestor "$batch" "$stamp" || { echo "stamp $stage is older than the batch commit"; return 1; }
  done
  echo "10 stage stamps at or after ${batch:0:7}"
}
s2() { # Java element-row probe: nothing raw left, the missing member is named
  limit 400 bash scripts/probes/element-row/run.sh java < /dev/null > "$work/java" 2>/dev/null || return 1
  [ "$(wc -l < "$work/java" | tr -d ' ')" = 22 ] && ! grep -q 'threw:' "$work/java" &&
    grep "$(printf 'java\tnull-member\t')" "$work/java" | grep -q 'refused: IllegalArgumentException: missing utf8 1' &&
    grep "$(printf 'java\tnull-member-map\t')" "$work/java" | grep -q 'refused: IllegalArgumentException: missing text' &&
    echo "22 lines, no threw:, missing member named"
}
s3() { # Python element-row probe
  PACKBIN_PROBE_PYTHON="${PACKBIN_PROBE_PYTHON:-python3.13}" limit 400 bash scripts/probes/element-row/run.sh python < /dev/null > "$work/py" 2>/dev/null || return 1
  grep "$(printf 'python\tnull-member\t')" "$work/py" | grep -q 'refused: TypeError: missing text' &&
    grep "$(printf 'python\tnull-item\t')" "$work/py" | grep -q 'refused: TypeError: items: an item has no value' &&
    ! grep -q 'threw:' "$work/py" && echo "python null-member and null-item refused, no threw:"
}
s4() { # Dart: no fixed wall-clock bound left, analyzer and format clean
  export PATH="/opt/homebrew/bin:$PATH"
  git grep -n -E 'lessThan\(1000\)|elapsedMilliseconds, lessThan' -- dart/test > "$work/fixed" && { cat "$work/fixed"; return 1; }
  (cd dart && limit 200 dart analyze --fatal-infos < /dev/null && limit 60 dart format --output=none --set-exit-if-changed . < /dev/null) > "$work/dart" 2>&1 || { tail -5 "$work/dart"; return 1; }
  tail -2 "$work/dart"
}
s5() { # C++ stub tests of the s390x compare and the ESP core pin
  limit 300 bash cpp/embedded/lib.test.sh < /dev/null > "$work/lib" 2>&1 || { tail -5 "$work/lib"; return 1; }
  limit 300 bash cpp/embedded/run-parts.test.sh < /dev/null > "$work/parts" 2>&1 || { tail -5 "$work/parts"; return 1; }
  tail -1 "$work/lib"; tail -1 "$work/parts"
}
s6() { [ "$(bash .github/workflows/tool-pin.sh arduino-esp32)" = 3.3.12 ] && grep -q 'arduino-esp32-core-pin.md' _docs/gotchas/INDEX.md && echo "pin 3.3.12, gotcha indexed"; }
s7() { # lib.test.sh and publish-pins.test.sh are clean; the sourced fragments arm.sh and examples.sh (their variables come
  # from run.sh) keep their older notes, and this loop adds none
  shellcheck cpp/embedded/lib.test.sh .github/workflows/publish-pins.test.sh || return 1
  local f base now first
  first="$(git log -1 --format=%H --grep='^Start: hygiene-loop121')"
  for f in cpp/embedded/arm.sh cpp/embedded/examples.sh; do
    base="$(git show "$first:$f" | shellcheck -s bash - 2> /dev/null | grep -c '^In ')"
    now="$(shellcheck "$f" 2> /dev/null | grep -c '^In ')"
    [ "$now" -le "$base" ] || { echo "$f: $now findings, $base before the loop"; return 1; }
  done
  echo "shellcheck: no finding added"
}
s8() { grep -q 'declared for another row class; this row is Row' README.md && grep -q 'missing utf8 1' README.md && grep -q "items: an item has no value" README.md &&
  grep -q 'repeat-last check of a scheme' README.md && echo "four README bullets present"; }
step "1. step 11 stage stamps (10 stages) at the batch commit or later" s1
step "2. Java element-row probe: 22 lines, no raw exception, missing member named" s2
step "3. Python element-row probe: null-member and null-item refused" s3
step "4. Dart: no fixed bound left, analyzer and format clean" s4
step "5. C++ stub tests (s390x percentage compare, ESP core pin)" s5
step "6. ESP core pinned at 3.3.12 and its gotcha indexed" s6
step "7. shellcheck clean on the changed shell scripts" s7
step "8. README bullets" s8
if [ "$fail" -eq 0 ]; then echo "smoke 121: 8/8 PASS"; else echo "smoke 121: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
