# Loop 25 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: dev (no worktree)

The agent runs the script below itself (owner rule, `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate) at the commit before the close commit. It prints `START n/N title` and `STAGE n/N title: PASS (Ns) <result>` or `FAIL` with the last log lines, and `DONE P/N stages passed` at the end. All 13 must pass.

What the 13 checks prove (each ties to a task of the loop):

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | scaffold: golden row, `report-row`, hostile case file (65 cases, seven package names; the checker uses one word list per pack case), `run-suite` (the six fail on a missing manifest, M1 to M3), embedded harness, ring wiring, `publish-go.test.sh` | AZ-2477 |
| 3 | Go in the CI container: gofmt, vet, race tests, AC-10 speed bound without `-race`, 60 s `FuzzUnpack`, dependency check | AZ-2475 (the memory test is opt-in and not part of this run) |
| 4 to 9 | TypeScript 967, C# 2005, Python 1494, Rust 686, Java 2586 checks, C++ (GCC 16 `-Werror`) in the CI containers | AZ-2472 (C++ id range), AZ-2473 (C# nested dictionaries), AZ-2474 (Python `ValueError`), AZ-2476 and AZ-2478 (probes) |
| 10 | embedded ARM: M0+, M3 QEMU, M4F flash 8152 of 8192 B (margin 40 B) and stack 456 of 512 B, s390x | AZ-2472 (`cpp/include` changed; the margins must not move) |
| 11 | cross-language ring with Go: 15 payload kinds, the session ring and `pack-session`, the position check; the C# and C++ drivers are built once into a private directory | AZ-2477 follow-up (`language-pair.sh`) |
| 12 | AC-10 in C# (Release) | AC-10 |
| 13 | publish gate tests with seven languages (the real golden gate in Docker with Go) | publish path unchanged: the gate must stay green |

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
LOGS="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
mkdir -p "$LOGS/py" test-results
ln -sf /opt/homebrew/bin/python3.14 "$LOGS/py/python3"
TOTAL=13
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
    echo "STAGE $n/$TOTAL $title: PASS (${secs}s) $(grep -E "$expect" "$log" | tail -n 1 | cut -c1-120)"
  else
    echo "STAGE $n/$TOTAL $title: FAIL (${secs}s, exit $rc, expected /$expect/)"
    tail -n 12 "$log" | sed 's/^/    | /'
  fi
}
stage "branch is dev and the working tree is clean" 20 "^dev " bash -c 'test "$(git branch --show-current)" = dev && test -z "$(git status --short)" && echo "dev $(git rev-parse --short HEAD), tree clean"'
stage "scaffold: golden row, report-row, hostile cases, run-suite, embedded lib, ring wiring, publish-go" 900 "go release checks passed" \
  bash -c 'grep -qx 4001000065cd1d00a3e1110100 fixtures/golden.hex && bash .github/workflows/report-row.test.sh && bash fixtures/hostile/cases.test.sh && bash fixtures/hostile/check-cases.sh && bash .github/workflows/run-suite.test.sh && bash cpp/embedded/lib.test.sh && bash .github/workflows/ring-wiring.test.sh && bash .github/workflows/publish-go.test.sh'
stage "Go suite in the CI container (golang:1.27: gofmt, vet, race tests, speed bound, 60 s fuzz, dependencies)" 1500 "^ok[[:space:]]+github.com/zxsanny/packbin/go" \
  docker compose -f docker-compose.test.yml run --rm go
stage "TypeScript suite in the CI container (967 tests)" 900 "pass 967" docker compose -f docker-compose.test.yml run --rm typescript
stage "C# suite in the CI container (2005 tests)" 1200 "Passed: +2005" docker compose -f docker-compose.test.yml run --rm csharp
stage "Python suite in the CI container (1494 tests)" 1200 "1494 passed" docker compose -f docker-compose.test.yml run --rm python
stage "Rust suite in the CI container (686 tests)" 1800 "test result: ok. [1-9][0-9]{2,} passed" docker compose -f docker-compose.test.yml run --rm rust
stage "Java suite in the CI container (2586 checks)" 900 "PackbinTest checks: 2586" docker compose -f docker-compose.test.yml run --rm java
stage "C++ suite in the CI container (GCC 16, -Werror)" 900 "all tests passed" \
  bash -c 'make -C cpp clean && docker compose -f docker-compose.test.yml run --rm cpp'
stage "C++ embedded ARM targets (flash 8152 of 8192 B, stack 456 of 512 B expected, unchanged)" 2400 "embedded stage arm: 0 target" \
  docker compose -f docker-compose.test.yml run --rm cpp-embedded
stage "cross-language ring with Go (builds the C# and C++ drivers once, Python 3.14 first on PATH)" 2400 "language pairs passed" \
  env PATH="$LOGS/py:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
stage "AC-10 in C# (Release): 100 000 typed round trips under 1 second" 600 "fastest pass [0-9]+ ms|Passed: +[0-9]+" \
  dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
stage "publish gate tests with seven languages (Python 3.14 first on PATH)" 3000 "publish gate tests passed|publish gate: no failures" \
  env PATH="$LOGS/py:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/publish-gate.test.sh
dotnet build-server shutdown </dev/null > "$LOGS/shutdown.log" 2>&1 || true
echo "DONE $PASSED/$TOTAL stages passed (logs in $LOGS)"
SMOKE
```
