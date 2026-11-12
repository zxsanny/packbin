#!/usr/bin/env bash
# Loop 115 smoke (AZ-4241, does `dotnet test csharp` hang without a console logger?): one paste, PASS/FAIL per step.
# Run from the repository root. The 10 + 10 runs of the investigation are in record115.md; this repeats one of each.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
run() { # mode: plain | logger
  local args=(test csharp --nologo) start rc
  [ "$1" = logger ] && args+=(--logger "console;verbosity=normal")
  start=$(date +%s)
  MSBUILDDISABLENODEREUSE=1 limit 300 dotnet "${args[@]}" < /dev/null > "$work/$1.log" 2>&1; rc=$?
  echo "$1: exit $rc in $(( $(date +%s) - start )) s, load $(sysctl -n vm.loadavg | awk '{print $2}')"
  [ "$rc" -eq 0 ] && grep -q -E 'Total tests: 5474|Passed: +5474' "$work/$1.log"
}
s1() { run plain; }
s2() { run logger; }
s3() { # the gotcha records the counts and keeps the node-reuse variable
  grep -q 'does not hang without a console logger (loop 115, AZ-4241): 10 runs' _docs/AGENT_GOTCHAS.md &&
    grep -q 'gh run list --commit <sha>` matches only the full' _docs/AGENT_GOTCHAS.md && echo "2 gotcha lines"
}
s4() { # the queue item left the backlog and the loop claims it
  [ ! -e _docs/02_tasks/backlog/csharp-dotnet-test-hang-without-console-logger.md ] &&
    grep -q '^loop: 115$' _docs/02_task_plans/csharp-dotnet-test-hang-without-console-logger/problem.md && echo "claimed by loop 115"
}
step "1. dotnet test csharp without a logger ends, 5,474 tests pass (300 s limit)" s1
step "2. dotnet test csharp with the console logger ends, 5,474 tests pass (300 s limit)" s2
step "3. AGENT_GOTCHAS records the run counts and the gh full-SHA quirk" s3
step "4. the queue item is claimed by loop 115" s4
if [ "$fail" -eq 0 ]; then echo "smoke 115: 4/4 PASS"; else echo "smoke 115: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
