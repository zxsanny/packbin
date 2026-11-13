#!/usr/bin/env bash
# Loop 118 smoke (AZ-4251, C# sets the bit of a flags inside a flags; gotchas split): one paste, PASS/FAIL per step.
# Run from the repository root.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { # the C# tests of the fix, on both targets
  (cd csharp/tests && limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet test --nologo --filter "FullyQualifiedName~FlagsInFlagsTests" < /dev/null | grep -E "Passed!|Failed!") &&
    (cd csharp/tests && limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet test --nologo -p:PackbinTarget=netstandard2.0 --filter "FullyQualifiedName~FlagsInFlagsTests" < /dev/null | grep -E "Passed!")
}
s2() { # nine packages, every line same, C# packs the TypeScript bytes
  limit 400 bash scripts/probes/flags-in-flags/run.sh < /dev/null > "$work/probe" 2> "$work/probe.err" || return 1
  [ "$(wc -l < "$work/probe" | tr -d ' ')" = 40 ] && ! awk -F'\t' '$5 != "same"' "$work/probe" | grep -q . &&
    grep -q "$(printf 'csharp\tboth\tbuilt\t01030109\tsame')" "$work/probe" && echo "40 lines, all same; csharp both 01030109"
}
s3() { git status --short --untracked-files=all scripts/ csharp/ > "$work/st" && [ ! -s "$work/st" ] && echo "probe wrote nothing into the checkout"; }
s4() { shellcheck scripts/probes/flags-in-flags/run.sh scripts/probes/flags-in-flags/*/run.sh && echo "shellcheck clean"; }
s5() { # the gotchas split: the old file is gone, one index line per file, no live reference left
  [ ! -e _docs/AGENT_GOTCHAS.md ] || return 1
  local files lines
  files="$(find _docs/gotchas -name '*.md' ! -name INDEX.md | wc -l | tr -d ' ')"
  lines="$(grep -c '^- \[' _docs/gotchas/INDEX.md)"
  [ "$files" = "$lines" ] || return 1
  ! git grep -n 'AGENT_GOTCHAS' -- . ':(exclude)_docs/loops' ':(exclude)_docs/06_metrics' ':(exclude)_docs/02_tasks/done' \
      ':(exclude)_docs/05_security' ':(exclude)_docs/03_implementation' ':(exclude)_docs/02_document/ripple_log_*' \
      ':(exclude)_docs/02_document/tests/traceability-matrix*' ':(exclude)_docs/02_document/tests/blackbox-tests-*' \
      ':(exclude)_docs/02_task_plans' ':(exclude)_docs/LESSONS.md' ':(exclude)_docs/FRICTION.md' | grep -q . &&
    echo "$files gotcha files, $lines index lines, no live reference"
}
s6() { grep -q '^cloud_id: 1598226f-845f-4705-bcd1-5ed0c82d6119$' _docs/00_problem/tracker.md && grep -q '^mcp_server: ' _docs/00_problem/tracker.md && echo "tracker doc present"; }
step "1. C# FlagsInFlagsTests pass on net10.0 and netstandard2.0" s1
step "2. nine-package probe: 40 lines, all same" s2
step "3. the probe leaves the checkout clean" s3
step "4. shellcheck clean on the probe scripts" s4
step "5. gotchas split: no AGENT_GOTCHAS.md, index matches files" s5
step "6. _docs/00_problem/tracker.md names the Jira site" s6
if [ "$fail" -eq 0 ]; then echo "smoke 118: 6/6 PASS"; else echo "smoke 118: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
