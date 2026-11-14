#!/usr/bin/env bash
# Loop 126 smoke (scheme depth limit, AZ-4294 to AZ-4303): one paste, PASS/FAIL per step. Run from the repository root
# with a clean application tree, after step 11 (it reads the stage stamps). Needs python3.13 with PyYAML for the checks.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
probe=scripts/probes/scheme-depth
batch="$(git log -1 --format=%H --grep='Dart: a flag bit adds no level')"
s1() { # clean application tree; every stage stamp at the last code commit or later
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  local stage stamp
  for stage in go typescript csharp python rust java cpp swift dart scaffold publish-gate; do
    stamp="$(cat "test-results/stamps/$stage")" || return 1
    git merge-base --is-ancestor "$stamp" HEAD || return 1
    [ "$stage" = dart ] && { git merge-base --is-ancestor "$batch" "$stamp" || { echo "dart stamp older than ${batch:0:7}"; return 1; }; }
  done
  echo "11 stage stamps present; dart at the last code commit ${batch:0:7}"
}
s2() { # all nine probes: 60 lines, every one refused, none threw / crashed / timed out
  local out n bad
  out="$(limit 900 bash $probe/run.sh </dev/null 2>/dev/null)" || return 1
  n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  bad="$(printf '%s\n' "$out" | awk -F'\t' '$3 !~ /^refused/' | wc -l | tr -d ' ')"
  [ "$n" -eq 60 ] && [ "$bad" -eq 0 ] && echo "60 lines, all refused"
}
s3() { bash fixtures/hostile/check-cases.sh && bash fixtures/hostile/cases.test.sh; }
s4() { # the four shared cases are in the file and the contract is at 1.0.2 with the counting rule
  local id
  for id in construct_depth_when_257 construct_depth_group_257 pack_depth_when_256 pack_depth_group_256; do
    grep -q "^$id " fixtures/hostile/cases.txt || { echo "missing $id"; return 1; }
    grep -q "^## $id\$" fixtures/hostile/README.md || { echo "no section $id"; return 1; }
  done
  grep -q '^\*\*Version\*\*: 1.0.2' _docs/02_document/contracts/library/scheme-depth.md && grep -q 'Counting (1.0.1)' _docs/02_document/contracts/library/scheme-depth.md && echo "4 cases and sections; contract 1.0.2"
}
s5() { shellcheck -S warning .github/workflows/run-suite.sh $probe/run.sh $probe/case.sh && grep -q 'RUST_MIN_STACK=8388608' .github/workflows/run-suite.sh && echo "lint clean; RUST_MIN_STACK set"; }
s6() { # every package has its depth test file
  local f
  for f in typescript/tests/scheme-depth.test.ts python/tests/test_scheme_depth.py dart/test/checks/scheme_depth_test.dart csharp/tests/SchemeDepthTests.cs java/src/test/java/packbin/SchemeDepthTest.java go/scheme_depth_test.go swift/Tests/PackbinTests/SchemeDepthTests.swift rust/src/scheme_depth_tests.rs rust/tests/nostd_depth_tests.rs cpp/tests/core/scheme_depth_host_tests.cpp; do
    [ -f "$f" ] || { echo "missing $f"; return 1; }
  done
  echo "10 depth test files"
}
step "1. application tree clean; step 11 stamps present, Dart at the last code commit" s1
step "2. all nine probes: 60 lines, every one refused (1,000 / 5,000 / 50,000 levels)" s2
step "3. hostile case file checks pass" s3
step "4. the four shared cases, their sections and the contract" s4
step "5. shellcheck clean; RUST_MIN_STACK set for the Rust suite" s5
step "6. each package has its depth test file" s6
if [ "$fail" -eq 0 ]; then echo "smoke 126: 6/6 PASS"; else echo "smoke 126: FAIL (see above)"; fi
exit "$fail"
