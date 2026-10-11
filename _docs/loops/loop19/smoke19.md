# Loop 19 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: none (the loop ran on `dev`, as loops 11 to 18)

Paste the script below into a terminal. It runs every check in order, prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines, and ends with `N/M steps passed`. It takes about 8 minutes with the Docker images cached.

What the 13 checks prove (each ties to a task of the loop):

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | hostile case file well formed (33 cases, corruptions rejected), ring wiring checks, the `run-suite.sh` venv checks | AZ-2329, AZ-2331, AZ-2338, AZ-2341 |
| 3, 4 | C# 913 tests on net10.0 and on the `netstandard2.0` build | AZ-2329, 2331, 2335, 2337, 2338, 2342 |
| 5 | C# focused: round cap on pack, split-form rule, group element members only, `eq` range, count 0, lone buffer, hostile vectors | AZ-2329, 2331, 2332, 2335, 2337, 2338 |
| 6 | TypeScript 728 tests and strict `tsc` | AZ-2329, 2331, 2332, 2335, 2338 |
| 7 to 10 | Python 777, Rust 533, Java, C++ (GCC 16 `-Werror`) in the CI containers | AZ-2329 to AZ-2342 |
| 11 | embedded ARM: Cortex-M0+, M3 QEMU, M4F stack 448 of 512 B and flash 8064 of 8192 B, s390x | AZ-2334, AZ-2331 (C++ `Field::late`) |
| 12 | cross-language ring: every pair on the same bytes (needs `python3` 3.10+, so the script puts Python 3.14 first on `PATH`) | AZ-2330, AZ-2333 |
| 13 | AC-10: 100 000 public typed round trips under 1 second | project AC-10 |

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
step "hostile case file (33 cases), ring wiring and the run-suite venv checks" 300 "all checks passed" bash -c 'bash fixtures/hostile/cases.test.sh && bash fixtures/hostile/check-cases.sh && bash .github/workflows/ring-wiring.test.sh && bash .github/workflows/run-suite.test.sh'
step "C# suite on net10.0 (913 tests)" 600 "Passed: +913" dotnet test csharp --nologo -v n
step "C# suite on the netstandard2.0 build (913 tests)" 600 "Passed: +913" dotnet test csharp --nologo -v n -p:PackbinTarget=netstandard2.0
step "C#: round cap on pack, split-form rule, group element, eq range, count 0, lone buffer, hostile vectors" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~PackRoundCapTests|FullyQualifiedName~SplitFormDroppedBodyTests|FullyQualifiedName~GroupElementMembersOnlyTests|FullyQualifiedName~EqValueConstructionTests|FullyQualifiedName~TimesZeroWithValuesTests|FullyQualifiedName~LoneRoundValueTests|FullyQualifiedName~HostilePackVectorTests|FullyQualifiedName~HostileVectorTests"
step "TypeScript suite (728 tests) and strict tsc" 600 "pass 728" bash -c 'cd typescript && npm test && node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts'
step "Python suite in the CI container (777 tests)" 900 "777 passed" docker compose -f docker-compose.test.yml run --rm python
step "Rust suite in the CI container (533 tests)" 900 "test result: ok. 436 passed" docker compose -f docker-compose.test.yml run --rm rust
step "Java suite in the CI container" 900 "All session tests passed" docker compose -f docker-compose.test.yml run --rm java
step "C++ suite in the CI container (GCC 16, -Werror)" 900 "all tests passed" bash -c 'make -C cpp clean && docker compose -f docker-compose.test.yml run --rm cpp'
step "C++ embedded ARM targets: Cortex-M0+, M3 QEMU, M4F stack 448 of 512 B and flash 8064 of 8192 B, s390x" 1500 "embedded stage arm: 0 target" docker compose -f docker-compose.test.yml run --rm cpp-embedded
step "cross-language ring: every pair on the same bytes (Python 3.14 first on PATH)" 900 "language pairs passed" env PATH="$LOGS/py:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
step "AC-10: 100 000 public typed round trips in under 1 second (Release)" 600 "fastest pass [0-9]+ ms|Passed: +[0-9]+" dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
dotnet build-server shutdown </dev/null >/dev/null 2>&1
echo
echo "$PASSED/$TOTAL steps passed (logs in $LOGS)"
SMOKE
```

## Notes

- No credentials are needed. Step 11 builds nothing new when its Docker image is cached; a cold run takes a few minutes.
- Not in this script (they ran in the total test run, `_docs/03_implementation/test_run_loop19_report.md`): the publish gate (755 s), the ESP targets and the Pico example (the CI `embedded` job runs Pico; no arm64 toolchain here), and the two vcpkg checks (no vcpkg tool).
- Agent walk: no browser; the script above is the walk.

## Result

PASS. Owner run in the Terminal panel on `91aac65` (2026-10-11): `13/13 steps passed` (C# 913 on both targets, focused C# 143, TypeScript 728, Python 777, Rust 436 lib tests ok, Java, C++ in the GCC 16 container, embedded ARM 0 targets failed, ring `language pairs passed` in 104 s, AC-10). The agent trial run on `f0ec1d2` also passed 13/13 (ring 98 s). The gate was answered PASS in chat after the terminal output was read.

