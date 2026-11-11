#!/usr/bin/env bash
# Loop 109 smoke (AZ-4198): one paste, PASS/FAIL per step. Run from the repository root.
set -u
fail=0
step() { # name, command...
  local name="$1"; shift
  if "$@" > /tmp/smoke109.step.log 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; sed 's/^/      /' /tmp/smoke109.step.log | head -8; fail=1; fi
}
F=_docs/06_metrics/embedded-arm-dns_2026-11-11.md
joblog() { gh api "repos/zxsanny/packbin/actions/jobs/$1/logs" --allow-escape-sequences | sed 's/\x1b\[[0-9;]*m//g'; }

s1() { test -f "$F" && grep -q 'Not reproduced' "$F" && grep -q '43098620838' "$F" && grep -q '43100819627' "$F"; }
s2() { joblog 130648051396 | grep -q "Could not resolve 'archive.ubuntu.com'"; }
s3() {
  local id; for run in 43098620838 43100819627; do
    id="$(gh api "repos/zxsanny/packbin/actions/runs/$run/jobs" --jq '.jobs[0].id')"
    joblog "$id" > "/tmp/smoke109.$run.log"
    for p in host bridge host-network; do
      n="$(grep -cE "^[0-9T:.Z-]+ [0-9:]+ path=$p name=.* result=ok" "/tmp/smoke109.$run.log")"
      [ "$n" -ge 60 ] || { echo "run $run path $p: $n ok lookups"; return 1; }
    done
    b="$(grep -cE "^[0-9T:.Z-]+ [0-9:]+ path=build .* result=ok" "/tmp/smoke109.$run.log")"
    [ "$b" -ge 10 ] || { echo "run $run builds ok: $b"; return 1; }
    f="$(grep -cE "^[0-9T:.Z-]+ [0-9:]+ path=.* result=fail" "/tmp/smoke109.$run.log")"
    [ "$f" -eq 0 ] || { echo "run $run failed lookups: $f"; return 1; }
  done
  grep -q 'nameserver 168.63.129.16' /tmp/smoke109.43100819627.log && grep -q 'nameserver 127.0.0.53' /tmp/smoke109.43100819627.log
}
s4() { [ "$(gh run view 43100819627 --json conclusion --jq .conclusion)" = success ]; }
s5() { grep -q 'is not known' cpp/embedded/run.sh && grep -q 'is not known' cpp/embedded/Dockerfile && grep -q "$F" cpp/embedded/run.sh && grep -q "$F" cpp/embedded/Dockerfile; }
s6() { # the AZ-4198 commits touch only .github/, cpp/embedded/ and _docs/
  bad="$(git log --grep='AZ-4198' --name-only --format= | sort -u | grep -vE '^(\.github/|cpp/embedded/|_docs/)' || true)"
  [ -z "$bad" ] || { echo "$bad"; return 1; }
}
s7() { head -3 _docs/05_security/lite_loop109.md | grep -q 'loop 109' && grep -q '^Verdict: ESCALATE' _docs/05_security/lite_loop109.md && grep -q '0 Critical, 0 High, 0 Medium' _docs/05_security/lite_loop109.md; }
s8() { # dev run of the last application-source push
  sha="$(git log -1 --format=%H -- .github cpp csharp typescript dart README.md)"
  run="$(gh run list --workflow test.yml --branch dev --commit "$sha" --limit 1 --json databaseId,status,conclusion --jq '.[0] | "\(.databaseId) \(.status) \(.conclusion)"')"
  echo "run for ${sha:0:7}: $run"
  jobs="$(gh api "repos/zxsanny/packbin/actions/runs/${run%% *}/jobs" --paginate --jq '[.jobs[].conclusion] | map(select(. == "success")) | length')"
  total="$(gh api "repos/zxsanny/packbin/actions/runs/${run%% *}/jobs" --paginate --jq '.jobs | length')"
  echo "jobs success $jobs of $total"
  [ "$jobs" -eq 20 ] && [ "$total" -eq 20 ]
}
step "1 findings file says not reproduced and cites both runs" s1
step "2 the failing job log holds the quoted line" s2
step "3 both diagnostic logs: >=60 ok lookups per path, >=10 ok builds, 0 failed, resolvers as quoted" s3
step "4 run 43100819627 concluded success" s4
step "5 run.sh and Dockerfile comments say the cause is not known and cite the findings" s5
step "6 AZ-4198 commits touch only .github/, cpp/embedded/, _docs/" s6
step "7 security lite record: ESCALATE answered, 0 Critical/High/Medium" s7
step "8 test.yml of the last source push: 20 of 20 jobs success" s8
[ "$fail" -eq 0 ] && echo "SMOKE 109: ALL PASS" || echo "SMOKE 109: FAILED"
exit "$fail"
