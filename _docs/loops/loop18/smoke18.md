# Loop 18 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: none (the loop ran on `dev`, as loops 11 to 17)

Paste the script below into a terminal. It runs every check in order, prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines, and ends with `N/M steps passed`. It takes about 5 to 8 minutes (Docker is needed for the Python, Rust, Java and C++ CI containers and the embedded ARM stage). It was trial-run on this tree before it was handed over (12 of 13 on the first run; the one failure was a stale Mac-built C++ binary in `cpp/build`, fixed by `make -C cpp clean` in step 10; the fixed step passes).

What the 13 checks prove (each ties to a task of the loop):

| # | Check | Tasks |
|---|-------|-------|
| 1 | on `dev`, tree clean | — |
| 2 | hostile case file well formed (25 cases, 26 corruptions rejected) and the ring wiring checks | AZ-2126 AC-3, AZ-2194, AZ-2307 |
| 3, 4 | C# 844 tests on net10.0 and on the `netstandard2.0` build | AZ-2305, 2306, 2307, 2309, 2310, 2120, 2126 |
| 5 | C# focused: `when`/`times`/`repeat` as `flags` members, `eq(bool,true)` only, flags elements, collection checks | AZ-2120, AZ-2126, AZ-2305, AZ-2307 |
| 6 | TypeScript 642 tests and strict `tsc` | AZ-2126, AZ-2308, AZ-2120 |
| 7 to 10 | Python 692, Rust 479, Java, C++ (GCC 16 `-Werror`) in the CI containers | AZ-2120, AZ-2126, AZ-2308, AZ-2311, AZ-2304 |
| 11 | embedded ARM: Cortex-M0+, M3 QEMU, M4F stack 456 of 512 B and flash 7992 of 8192 B, s390x | AZ-2304 AC-4 |
| 12 | cross-language ring: every pair on the same bytes, C# in `listgroup`, `dictgroup`, `listflags` | AZ-2307 AC-2, AC-3, AZ-2120 AC-5 |
| 13 | AC-10: 100 000 public typed round trips under 1 second | project AC-10 |

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
LOGS="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
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
step "hostile case file (25 cases, 26 corruptions rejected) and ring wiring" 300 "ring wiring checks passed" bash -c 'bash fixtures/hostile/cases.test.sh && bash .github/workflows/ring-wiring.test.sh'
step "C# suite on net10.0 (844 tests)" 600 "Passed: +844" dotnet test csharp --nologo -v n
step "C# suite on the netstandard2.0 build (844 tests)" 600 "Passed: +844" dotnet test csharp --nologo -v n -p:PackbinTarget=netstandard2.0
step "C#: when, times, repeat as flags members; eq(bool,true) only; flags elements; collection checks" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~FlagsWhenMemberTests|FullyQualifiedName~FlagsRoundMemberTests|FullyQualifiedName~EqBoolTrueOnlyTests|FullyQualifiedName~FlagsElementTests|FullyQualifiedName~CollectionMemberTests|FullyQualifiedName~CollectionElementKindTests|FullyQualifiedName~DictionaryElementTypedRowTests"
step "TypeScript suite (642 tests) and strict tsc" 600 "pass 642" bash -c 'cd typescript && npm test && node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts'
step "Python suite in the CI container (692 tests)" 900 "692 passed" docker compose -f docker-compose.test.yml run --rm python
step "Rust suite in the CI container (479 tests)" 900 "test result: ok" docker compose -f docker-compose.test.yml run --rm rust
step "Java suite in the CI container" 900 "All session tests passed" docker compose -f docker-compose.test.yml run --rm java
step "C++ suite in the CI container (GCC 16, -Werror)" 900 "all tests passed" bash -c 'make -C cpp clean && docker compose -f docker-compose.test.yml run --rm cpp'
step "C++ embedded ARM targets: Cortex-M0+, M3 QEMU, M4F stack 456 of 512 B and flash, s390x" 1500 "embedded stage arm: 0 target" docker compose -f docker-compose.test.yml run --rm cpp-embedded
step "cross-language ring: C# in listgroup, dictgroup, listflags; every pair on the same bytes" 900 "language pairs passed" env PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
step "AC-10: 100 000 public typed round trips in under 1 second (Release)" 600 "fastest pass [0-9]+ ms|Passed: +[0-9]+" dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
dotnet build-server shutdown </dev/null >/dev/null 2>&1
echo
echo "$PASSED/$TOTAL steps passed (logs in $LOGS)"
SMOKE
```

## Notes

- No credentials are needed. Step 11 builds nothing new when its Docker image is cached (it took 7 s in the trial); a cold run takes a few minutes.
- Not in this script (they ran in the total test run, `_docs/03_implementation/test_run_loop18_report.md`): the publish gate (450 s), the ESP targets and the Pico example (the CI `embedded` job runs Pico; it has no arm64 toolchain here).
- Agent walk: no browser; the script above is the walk.

## Result

PASS. Owner run in the Terminal panel on `d365e06` (2026-10-11): `13/13 steps passed` (C# 844 on both targets, focused C# 137, TypeScript 642, Python 692, Rust, Java, C++ in the GCC 16 container, embedded ARM 0 targets failed, ring `language pairs passed` in 84 s, AC-10). The gate was answered PASS in chat after a misclick on FAIL.
