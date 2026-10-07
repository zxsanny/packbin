# Loop 17 smoke — proposed checks

LOCAL_URL: none (a library; no site to open)
Branch: none (the loop ran on `dev`, as loops 11 to 16)

Paste the script below into a terminal. It runs every check in order, prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines, and ends with `N/M steps passed`. It takes about 6 minutes (the ring 75 s, the container suite and the C# suites the rest). Nothing is installed or changed in the repo; logs go to a temporary directory.

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
LOGS="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
PASSED=0
TOTAL=11
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
step "branch is dev and csharp/ has no uncommitted change" 20 "^dev " bash -c 'test "$(git branch --show-current)" = dev && test -z "$(git status --short -- csharp)" && echo "dev $(git rev-parse --short HEAD), csharp/ clean"'
step "C# suite on net10.0 (649 tests)" 600 "Passed: +649" dotnet test csharp --nologo -v n
step "C# suite on the netstandard2.0 build (649 tests)" 600 "Passed: +649" dotnet test csharp --nologo -v n -p:PackbinTarget=netstandard2.0
step "README C# example packs the README hex, nested rows bind per scope" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~TypedBindingTests|FullyQualifiedName~TypedParityTests|FullyQualifiedName~NestedRowFlagByteTests"
step "split bits numbered by field order, a handle shared by two schemes" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~SplitBitOrderTests|FullyQualifiedName~FlagGroupCopyTests|FullyQualifiedName~FlagGroupPresenceTests|FullyQualifiedName~U2PresenceTests"
step "counts must be integers, lone values in rounds, strict numbers, group elements" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~CountKindTests|FullyQualifiedName~CountOverflowTests|FullyQualifiedName~LoneRoundValueTests|FullyQualifiedName~StrictNumberTests|FullyQualifiedName~GroupElementTests"
step "hostile vectors and hostile session payloads in C#" 300 "Passed: +[0-9]+" dotnet test csharp --nologo -v n --no-build --filter "FullyQualifiedName~HostileVectorTests|FullyQualifiedName~HostileSessionTests|FullyQualifiedName~HostileUnpackTests"
step "AC-10: 100 000 public typed round trips in under 1 second (Release)" 600 "fastest pass [0-9]+ ms" dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" --logger "console;verbosity=detailed"
step "cross-language ring: C# against TypeScript, Python, Rust, Java, C++ on the same bytes" 900 "language pairs passed" env PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/language-pair.sh
step "the NuGet package carries both frameworks" 300 "netstandard2.0.*net10.0|net10.0.*netstandard2.0" bash -c "dotnet pack csharp/Packbin.csproj -c Release -o '$LOGS/pack' --nologo -v q >/dev/null && unzip -l '$LOGS/pack/'*.nupkg | grep -oE 'lib/(netstandard2.0|net10.0)/Packbin.dll' | sort -u | tr '\n' ' '"
step "CI container suite (docker compose, both C# targets)" 900 "Passed: +649" docker compose -f docker-compose.test.yml run --rm csharp
dotnet build-server shutdown </dev/null >/dev/null 2>&1
echo
echo "$PASSED/$TOTAL steps passed (logs in $LOGS)"
SMOKE
```

## Perform these checks (what each step proves)

- [ ] 1 the branch is `dev` and the C# sources have no uncommitted change
- [ ] 2 and 3 the C# package passes all 649 tests on both targets (AZ-2092 to AZ-2191, the multi-target build)
- [ ] 4 the README C# example works (AZ-2092 AC-2, AC-3), nested rows no longer overwrite outer members (AC-1)
- [ ] 5 split bits follow field order, a handle is shared by two schemes, nested flag groups and `u2` count as present (AZ-2135, AZ-2128, AZ-2180)
- [ ] 6 a count must name an integer, a lone value in a round, strict numbers, group elements (AZ-2181, AZ-2182, AZ-2191, AZ-2119)
- [ ] 7 the hostile vectors and the session payloads that C# must refuse (AZ-2114)
- [ ] 8 the project bound AC-10 (1 second) on the public typed path (AZ-2093); the figure printed is the fastest pass
- [ ] 9 the ring: C# packs and unpacks the same bytes as the other five packages
- [ ] 10 the package built for release holds `lib/netstandard2.0` and `lib/net10.0`
- [ ] 11 the same suite in the CI container

## Notes

No credentials. Step 9 needs the macOS sysroot recipe from `_docs/AGENT_GOTCHAS.md` (already in the script). Not covered here, covered by the loop's total test run (`test_run_loop17_report.md`): the other five package suites, `publish-gate.test.sh`, the scaffold checks. Not run at all: the CI `embedded` job.

## Agent walk

The agent trial-ran the script on 2026-10-07 against `412ae3a` plus the uncommitted docs, README and one comment in `language-pair.sh` (no `csharp/` change): **11/11 steps passed**. Times: net10.0 6 s and netstandard2.0 5 s (incremental builds), filtered groups 1 to 3 s (24, 32, 151 and 74 tests), AC-10 Release 327 ms for 100 000 round trips, ring 70 s (`language pairs passed`), package lists `lib/net10.0/Packbin.dll` and `lib/netstandard2.0/Packbin.dll`, container suite 24 s (649). No browser: nothing in this loop has a UI.
