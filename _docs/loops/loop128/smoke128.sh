#!/usr/bin/env bash
# Loop 128 smoke (C# typed element row counts two levels, AZ-4314, D20): one paste, PASS/FAIL per step.
# Run from the repository root with a clean application tree, after step 11 (it reads the stage stamps).
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
batch="$(git log -1 --format=%H --grep='typed list or dict of rows counts two levels')"
s1() {
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  local stage
  for stage in csharp ring ac10; do
    git merge-base --is-ancestor "$batch" "$(cat "test-results/stamps/$stage")" || { echo "$stage stamp older than ${batch:0:7}"; return 1; }
  done
  echo "csharp, ring and ac10 stamps at or after ${batch:0:7}"
}
s2() { # the C# probe: 6 lines, all refused
  local out; out="$(limit 300 bash scripts/probes/scheme-depth/run.sh csharp </dev/null 2>/dev/null)" || return 1
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 6 ] && [ "$(printf '%s\n' "$out" | awk -F'\t' '$3 ~ /^refused/' | wc -l | tr -d ' ')" -eq 6 ] && echo "6 lines, all refused"
}
s3() { grep -q '^\*\*Version\*\*: 1.0.3' _docs/02_document/contracts/library/scheme-depth.md && grep -q 'typed `list(row)` is two levels' _docs/02_document/contracts/library/scheme-depth.md && echo "contract 1.0.3 states the rule"; }
s4() { grep -q 'Ac1_Construct_ATypedListOfRowsIsTwoLevels_D20' csharp/tests/SchemeDepthTests.cs && ! grep -q 'IsElementRow == true ? 0' csharp/SchemeOrder.cs && echo "D20 test present; element row counts one level"; }
s5() { grep -q 'decided 2026-11-14: A' _docs/OPERATOR_TODO.md && echo "D20 recorded as decided"; }
step "1. application tree clean; csharp, ring and ac10 stamps at the batch commit" s1
step "2. the C# probe: six lines, all refused" s2
step "3. the contract states the rule (1.0.3)" s3
step "4. the D20 test exists and the element row is counted" s4
step "5. D20 recorded as decided" s5
if [ "$fail" -eq 0 ]; then echo "smoke 128: 5/5 PASS"; else echo "smoke 128: FAIL (see above)"; fi
exit "$fail"
