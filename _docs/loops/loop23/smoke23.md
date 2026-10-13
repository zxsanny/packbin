# Loop 23 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: dev (no worktree)

The agent runs the script below itself (owner rule, `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate) at the commit before the close commit. It prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines, and ends with `N/M steps passed`. About 5 minutes with warm caches (the step 11 run at `807e718` passed the same checks in about 6 minutes plus the publish gate).

What the 13 checks prove (each ties to a task of the loop):

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | hostile case file well formed (65 cases), ring wiring checks, the `run-suite.sh` venv checks | AZ-2431 (C++ body-rule text), G4 |
| 3, 4 | C# 1978 tests on net10.0 and on the `netstandard2.0` build | AZ-2436 |
| 5 | C# focused: U11 in six nested positions, the short count list, the U11 top level, the loader rule tables | AZ-2436, AZ-2437 parity |
| 6 | TypeScript 967 tests and strict `tsc` | AZ-2434, AZ-2436 |
| 7 to 10 | Python 1476, Rust 673 across 21 binaries, Java 2540 checks, C++ (GCC 16 `-Werror`) in the CI containers | AZ-2431 to AZ-2437 |
| 11 | embedded ARM: Cortex-M0+, M3 QEMU, M4F stack 456 of 512 B and flash 8152 of 8192 B (margin 40 B), s390x | AZ-2431 (0 B) |
| 12 | cross-language ring: every pair on the same bytes (Python 3.14 first on `PATH`) | wire bytes of accepted rows unchanged |
| 13 | AC-10: 100 000 public typed round trips under 1 second (Release) | no per-round cost added |

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
step "hostile case file (65 cases), ring wiring and the run-suite venv checks" 600 "hostile cases ok: 65" bash -c 'bash fixtures/hostile/cases.test.sh && bash fixtures/hostile/check-cases.sh && bash .github/workflows/ring-wiring.test.sh && bash .github/workflows/run-suite.test.sh'
step "C# suite on net10.0 (1978 tests)" 900 "Passed: +1978" dotnet test csharp --nologo -v n
step "C# suite on the netstandard2.0 build (1978 tests)" 900 "Passed: +1978" dotnet test csharp --nologo -v n -p:PackbinTarget=netstandard2.0
step "C#: U11 in nested positions and the short count list (AZ-2436), U11 top level, hostile loaders and rule tables" 600 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build -p:PackbinTarget=netstandard2.0 --filter "FullyQualifiedName~NoValueCountNestedTests|FullyQualifiedName~CountBehindClearWhenTests|FullyQualifiedName~HostilePackVectorTests|FullyQualifiedName~HostileVectorTests"
step "TypeScript suite (967 tests: bigint count U23, U11 nested) and strict tsc" 900 "pass 967" bash -c 'cd typescript && npm test && node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts && echo "tsc strict ok"'
step "Python suite in the CI container (1476 tests: short count list AZ-2437, raised limit, U11 nested)" 900 "1476 passed" docker compose -f docker-compose.test.yml run --rm python
step "Rust suite in the CI container (673 tests across 21 binaries: repeat values refused U22, G5, G6)" 1500 "test result: ok. [1-9][0-9]{2,} passed" docker compose -f docker-compose.test.yml run --rm rust
step "Java suite in the CI container (2540 checks)" 900 "PackbinTest checks: 2540" docker compose -f docker-compose.test.yml run --rm java
step "C++ suite in the CI container (GCC 16, -Werror: eq id range U19, empty-body rule G2, bias -1 trace U20)" 900 "all tests passed" bash -c 'make -C cpp clean && docker compose -f docker-compose.test.yml run --rm cpp'
step "C++ embedded ARM targets: M0+, M3 QEMU, M4F stack 456 of 512 B and flash 8152 of 8192 B, s390x" 2400 "embedded stage arm: 0 target" docker compose -f docker-compose.test.yml run --rm cpp-embedded
step "cross-language ring: every pair on the same bytes (Python 3.14 first on PATH)" 1500 "language pairs passed" env PATH="$LOGS/py:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
step "AC-10: 100 000 public typed round trips in under 1 second (Release)" 600 "fastest pass [0-9]+ ms|Passed: +[0-9]+" dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
dotnet build-server shutdown </dev/null >/dev/null 2>&1
echo
echo "$PASSED/$TOTAL steps passed (logs in $LOGS)"
SMOKE
```

## Result

PASS. Agent run on `1e1c23e` (2026-10-13), owner rule of 2026-10-12 (`_docs/04_deploy/deployment_procedures.md` § Loop smoke gate): `13/13 steps passed` (tree clean on `dev`; hostile case file 65; C# 1978 on net10.0 and on netstandard2.0 and 265 focused; TypeScript 967 with strict `tsc`; Python 1476 in 47 s; Rust 489 lib (673 across binaries); Java 2540 checks; C++ GCC 16 `-Werror`; embedded ARM 0 targets failed; ring 82 s; AC-10 pass). Host load 20 to 94 during the run (macOS XProtect scans); no step failed. Not in this script and not run locally: the ESP targets of `cpp-embedded-esp` and the vcpkg checks; the CI `embedded` job runs the ESP targets on the push.
