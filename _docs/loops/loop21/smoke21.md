# Loop 21 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: none (the loop ran on `dev`, as loops 11 to 19)

Paste the script below into a terminal. It runs every check in order, prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines, and ends with `N/M steps passed`. It takes about 5 minutes with warm caches (agent trial run on `6c03a2b`: 13/13 steps passed; the ring takes 90 s, the Python and Rust containers 30 to 40 s each) and up to about 30 minutes cold; do not let the laptop sleep, or a step can pass its time limit.

What the 13 checks prove (each ties to a task of the loop):

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | hostile case file well formed (55 cases, corruptions rejected), ring wiring checks, the `run-suite.sh` venv checks | AZ-2394 |
| 3, 4 | C# 1479 tests on net10.0 and on the `netstandard2.0` build | AZ-2373, AZ-2381 to AZ-2394 |
| 5 | C# focused: slot rule, short optional lists, clear-bit and count rules, empty round body, exact integer types, row-bound rounds, dict-in-round, count texts | AZ-2373, 2381 to 2390, 2393 |
| 6 | TypeScript 880 tests (the reference package of the slot rule) and strict `tsc` | AZ-2382, 2383, 2390, 2391 |
| 7 to 10 | Python 1003, Rust 625, Java 2153 checks, C++ (GCC 16 `-Werror`) in the CI containers | AZ-2373, AZ-2381 to AZ-2394 |
| 11 | embedded ARM: Cortex-M0+, M3 QEMU, M4F stack 456 of 512 B and flash 8152 of 8192 B (margin 40 B), s390x | AZ-2385, AZ-2390 |
| 12 | cross-language ring: every pair on the same bytes (needs `python3` 3.10+, so the script puts Python 3.14 first on `PATH`) | wire bytes of accepted rows unchanged |
| 13 | AC-10: 100 000 public typed round trips under 1 second (Release); loop 21 adds construction-time walks only, no per-round cost | AZ-2390 |

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
LOGS="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
mkdir -p "$LOGS/py"; ln -s "$(command -v python3.14 || echo /opt/homebrew/bin/python3.14)" "$LOGS/py/python3"
PASSED=0
TOTAL=13
n=0
step() {
  # step "title" limit-seconds "expected text in the log" command...
  local title="$1" limit="$2" expect="$3"; shift 3
  n=$((n + 1))
  echo "[$n/$TOTAL] $title"
  local start=$(date +%s) log="$LOGS/step$n.log" rc
  perl -e 'alarm shift; exec @ARGV' -- "$limit" "$@" </dev/null > "$log" 2>&1
  rc=$?
  local secs=$(( $(date +%s) - start ))
  if [ "$rc" -eq 0 ] && grep -qE "$expect" "$log"; then
    echo "    PASS (${secs}s) $(grep -E "$expect" "$log" | tail -n 1 | cut -c1-110)"
    PASSED=$((PASSED + 1))
  else
    echo "    FAIL (${secs}s, exit $rc; expected /$expect/) last lines of $log:"
    tail -n 8 "$log" | sed 's/^/      | /'
  fi
}
step "branch is dev and the working tree is clean" 20 "^dev " bash -c 'test "$(git branch --show-current)" = dev && test -z "$(git status --short)" && echo "dev $(git rev-parse --short HEAD), tree clean"'
step "hostile case file (55 cases), ring wiring and the run-suite venv checks" 600 "hostile cases ok: 55" bash -c 'bash fixtures/hostile/cases.test.sh && bash fixtures/hostile/check-cases.sh && bash .github/workflows/ring-wiring.test.sh && bash .github/workflows/run-suite.test.sh'
step "C# suite on net10.0 (1479 tests)" 900 "Passed: +1479" dotnet test csharp --nologo -v n
step "C# suite on the netstandard2.0 build (1479 tests)" 900 "Passed: +1479" dotnet test csharp --nologo -v n -p:PackbinTarget=netstandard2.0
step "C#: slot rule, short lists, clear-bit counts, empty round body, exact integer types, row rounds, dict-in-round, count texts" 600 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build -p:PackbinTarget=netstandard2.0 --filter "FullyQualifiedName~RoundSlotWidthTests|FullyQualifiedName~RoundSlotWidthTypedTests|FullyQualifiedName~EmptyRoundBodyTests|FullyQualifiedName~ShortOptionalListTests|FullyQualifiedName~SplitTimesClearBitTests|FullyQualifiedName~CountBehindClearWhenTests|FullyQualifiedName~ExactIntegerTypeTests|FullyQualifiedName~RowRoundTests|FullyQualifiedName~RowRoundMemberTests|FullyQualifiedName~RoundCollectionMemberTests|FullyQualifiedName~CountTextAndLimitsTests"
step "TypeScript suite (880 tests) and strict tsc" 900 "pass 880" bash -c 'cd typescript && npm test && node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts && echo "tsc strict ok"'
step "Python suite in the CI container (1003 tests)" 900 "1003 passed" docker compose -f docker-compose.test.yml run --rm python
step "Rust suite in the CI container (625 tests)" 1500 "test result: ok. [1-9][0-9]{2,} passed" docker compose -f docker-compose.test.yml run --rm rust
step "Java suite in the CI container (2153 checks)" 900 "PackbinTest checks: 2153" docker compose -f docker-compose.test.yml run --rm java
step "C++ suite in the CI container (GCC 16, -Werror)" 900 "all tests passed" bash -c 'make -C cpp clean && docker compose -f docker-compose.test.yml run --rm cpp'
step "C++ embedded ARM targets: M0+, M3 QEMU, M4F stack 456 of 512 B and flash 8152 of 8192 B, s390x" 2400 "embedded stage arm: 0 target" docker compose -f docker-compose.test.yml run --rm cpp-embedded
step "cross-language ring: every pair on the same bytes (Python 3.14 first on PATH)" 1500 "language pairs passed" env PATH="$LOGS/py:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
step "AC-10: 100 000 public typed round trips in under 1 second (Release)" 600 "fastest pass [0-9]+ ms|Passed: +[0-9]+" dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
dotnet build-server shutdown </dev/null >/dev/null 2>&1
echo
echo "$PASSED/$TOTAL steps passed (logs in $LOGS)"
SMOKE
```

## Notes

- No credentials are needed. Step 11 builds nothing new when its Docker image is cached; a cold run takes a few minutes.
- Not in this script (they ran in the total test run, `_docs/03_implementation/test_run_loop21_report.md`): the publish gate, the ESP targets (the Pico example fails on this host by design; the CI `embedded` job runs it) and the two real-vcpkg checks.
- Agent walk: no browser; the script above is the walk.

## Result

PASS. Agent run on `388d2a2` (2026-10-12), owner rule of 2026-10-12 (`_docs/04_deploy/deployment_procedures.md` § Loop smoke gate): `13/13 steps passed` (hostile case file 55, C# 1479 on both targets and 442 focused, TypeScript 880 with strict `tsc`, Python 1003, Rust, Java 2153 checks, C++ GCC 16 `-Werror`, embedded ARM 0 targets failed, ring "language pairs passed", AC-10 timing). Two script notes, fixed in this file after the run: the step 11 title still carried the loop 20 numbers (the run itself checks "0 target(s) failed"; the real numbers are stack 456 of 512 B and flash 8152 of 8192 B from `test_run_loop21_report.md`), and the Rust step regex `[0-9]+ passed` also matched an empty target (`0 passed`); it is now `[1-9][0-9]{2,} passed` (the lib target runs 472+). The step 11 total run counted Rust 625.
