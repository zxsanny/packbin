# Loop 26 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: dev (no worktree)

The agent runs the script below itself (owner rule, `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate and § Loop test script) at the commit before the close commit. It prints `START n/N title` and `STAGE n/N title: PASS (Ns) <result>` or `FAIL` with the last log lines, and `DONE P/N stages passed` at the end. All 5 must pass. Step 11 stamped every stage in `test-results/stamps`, so step 2 re-runs only the stages whose files changed after it (the steps 12 to 17 commits touch `_docs/` only, which no stage covers).

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | `scripts/loop-tests.sh`: every stage passed or skipped as unchanged since its stamp (swift in the `swift:6.3.3` container, the seven other suites, scaffold, ARM, ring, AC-10, publish gate) | AZ-2513 to AZ-2524 |
| 3 | strict release build on the Mac (`-warnings-as-errors`, `-strict-concurrency=complete`) | AZ-2513, SW-9 |
| 4 | `swift test` on the Mac: 340 tests in 56 suites | SW-1 to SW-16 |
| 5 | the hostile case checker (65 cases, eight package names) and the README Swift code check (inside step 4: `ReadmeExampleTests`) | AZ-2519, AZ-2524 |

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
LOGS="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
mkdir -p test-results
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
TOTAL=5
n=0
PASSED=0
echo "COMMIT $(git rev-parse --short HEAD) tree: $(git status --short | wc -l | tr -d ' ') changed paths; load: $(uptime | sed 's/.*load/load/')"
stage() {
  # stage "title" limit-seconds "expected regex" command...
  local title="$1" limit="$2" expect="$3"; shift 3
  n=$((n + 1))
  local start log rc secs
  start=$(date +%s); log="$LOGS/stage$n.log"
  echo "START $n/$TOTAL $title (log $log)"
  perl -e 'alarm shift; exec @ARGV' -- "$limit" "$@" </dev/null > "$log" 2>&1
  rc=$?
  secs=$(( $(date +%s) - start ))
  if [ "$rc" -eq 0 ] && grep -qE "$expect" "$log"; then
    PASSED=$((PASSED + 1))
    echo "STAGE $n/$TOTAL $title: PASS (${secs}s) $(grep -E "$expect" "$log" | tail -n 1 | cut -c1-140)"
  else
    echo "STAGE $n/$TOTAL $title: FAIL (${secs}s, exit $rc, expected /$expect/)"
    tail -n 12 "$log" | sed 's/^/    | /'
  fi
}
stage "branch is dev and the working tree is clean" 20 "^dev " bash -c 'test "$(git branch --show-current)" = dev && test -z "$(git status --short)" && echo "dev $(git rev-parse --short HEAD), tree clean"'
stage "scripts/loop-tests.sh: every stage passed or skipped as unchanged since its stamp" 4500 "^RESULT .* 0 failed" bash scripts/loop-tests.sh
stage "Swift strict release build on the Mac" 900 "Build complete" swift build -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
stage "Swift tests on the Mac (340 tests in 56 suites)" 900 "Test run with 340 tests in 56 suites passed" \
  swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete -Xswiftc -F -Xswiftc "$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L"
stage "hostile case checker: 65 cases, eight package names" 120 "hostile cases ok: 65" bash fixtures/hostile/check-cases.sh
dotnet build-server shutdown </dev/null > "$LOGS/shutdown.log" 2>&1 || true
echo "DONE $PASSED/$TOTAL stages passed (logs in $LOGS)"
SMOKE
```

## Result

PASS. Agent run on `735cec7` (2026-10-14, owner rule of 2026-10-12 in `deployment_procedures.md`): the script printed `DONE 5/5 stages passed`.

- The first run (at `d92a752`) printed 4/5: stage 4 expected the old count `335 tests in 55 suites` while the suite had grown to 340 tests in 56 after the security fixes (all 340 passed). The script was wrong, not the check: the expected count was corrected, committed (`735cec7`) and the whole script run again.
- Stage 2 skipped all 13 stages as unchanged since their stamps: the four stages that changed after the first step 11 invocations (`swift` 741 s in the `swift:6.3.3` container, scaffold 198 s, ring 73 s, publish gate 1 338 s) had passed on the fourth step 11 invocation at `d92a752`.
