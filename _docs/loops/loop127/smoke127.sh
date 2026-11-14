#!/usr/bin/env bash
# Loop 127 smoke (hygiene: shared fields in the depth check, AZ-4306 to AZ-4308): one paste, PASS/FAIL per step.
# Run from the repository root with a clean application tree, after step 11 (it reads the stage stamps).
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
probe=scripts/probes/scheme-depth
s1() { # clean application tree; stage stamps are ancestors of HEAD and typescript / ring are at the last code commit
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  local stage stamp last
  last="$(git log -1 --format=%H --grep='flags element counts its wrapper group')"
  for stage in go typescript csharp python rust java cpp swift dart scaffold publish-gate ring; do
    stamp="$(cat "test-results/stamps/$stage")" || return 1
    git merge-base --is-ancestor "$stamp" HEAD || return 1
  done
  for stage in typescript ring; do
    git merge-base --is-ancestor "$last" "$(cat "test-results/stamps/$stage")" || { echo "$stage stamp older than ${last:0:7}"; return 1; }
  done
  echo "stamps present; typescript and ring at the last code commit ${last:0:7}"
}
s2() { # all nine probes still print 60 refused lines
  local out n bad
  out="$(limit 900 bash $probe/run.sh </dev/null 2>/dev/null)" || return 1
  n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  bad="$(printf '%s\n' "$out" | awk -F'\t' '$3 !~ /^refused/' | wc -l | tr -d ' ')"
  [ "$n" -eq 60 ] && [ "$bad" -eq 0 ] && echo "60 lines, all refused"
}
s3() { # AC-1 of AZ-4306: a 60-level diamond is answered in TypeScript within 2 s (node runs the source)
  cat > "$work/diamond.ts" <<'TS'
import { u8, when, eq, scheme, type Field } from "/Users/zxsanny/dev/zxsanny/packbin/typescript/src/index.ts"
const named = (name: string) => new Function("r", `return r.${name}`) as (r: any) => unknown
let inner: Field[] = [u8(1, named("b"))]
for (let i = 0; i < 60; i++) inner = [when(1, eq(0, 1), [...inner, ...inner])]
const t0 = Date.now()
try { scheme(1, u8(0, named("a")), ...inner) } catch (e) { console.log("refused", Date.now() - t0, "ms", String(e).slice(0, 60)) }
TS
  local out; out="$(limit 20 node "$work/diamond.ts" </dev/null)" || return 1
  printf '%s\n' "$out"
  printf '%s\n' "$out" | grep -q '^refused' && [ "$(printf '%s\n' "$out" | awk '{print $2}')" -lt 2000 ]
}
s4() { # no file of the loop over 500 lines (the C# split)
  local n; n="$(wc -l < csharp/tests/HostilePackVectorTests.cs | tr -d ' ')"
  [ "$n" -le 500 ] && echo "HostilePackVectorTests.cs $n lines"
}
s5() { # the new test files exist
  local f
  for f in typescript/src/scheme-depth.ts dart/test/checks/scheme_depth_shared_test.dart swift/Tests/PackbinTests/SchemeDepthSharedTests.swift csharp/tests/SchemeDepthSharedTests.cs csharp/tests/SchemeDepthBuildTimeTests.cs go/scheme_depth_shared_test.go rust/tests/round_depth_tests.rs; do
    [ -f "$f" ] || { echo "missing $f"; return 1; }
  done
  echo "7 files present"
}
s6() { shellcheck -S warning $probe/run.sh $probe/case.sh && echo "lint clean"; }
step "1. application tree clean; stage stamps present, TypeScript and ring at the last code commit" s1
step "2. all nine probes: 60 lines, every one refused" s2
step "3. a 60-level diamond is refused by TypeScript in under 2 s" s3
step "4. the C# test file is within 500 lines" s4
step "5. the new test files are present" s5
step "6. shellcheck clean on the probe scripts" s6
if [ "$fail" -eq 0 ]; then echo "smoke 127: 6/6 PASS"; else echo "smoke 127: FAIL (see above)"; fi
exit "$fail"
