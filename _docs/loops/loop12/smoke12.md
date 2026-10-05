# Loop 12 smoke — proposed checks

LOCAL_URL: none (libraries; no UI, no local server)
Branch: dev (no worktree, same as loop 11)
HEAD: 0429211 (code), later changes touch `_docs/` only

## One-paste script

Paste into a terminal (zsh or bash). It runs every check below in order, prints PASS / FAIL per step with its time and a one-line result, shows the last lines of a failing step, and ends with `N/15 steps passed`. About 2.5 minutes with warm caches. Agent trial run 2026-10-05 15:23: 15/15 passed.

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
export PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"
logs=$(mktemp -d); n=0; failed=0; total=15
step() { # step <title> <ok|err> <must-match regex> <detail regex> -- command...
  local title=$1 mode=$2 want=$3 show=$4; shift 5
  n=$((n+1)); local out="$logs/$n.log" t0=$SECONDS
  printf '\n[%2d/%d] %s ...\n' "$n" "$total" "$title"
  "$@" </dev/null >"$out" 2>&1; local rc=$?   # </dev/null: docker would read the rest of this script from stdin
  local good=1
  if [ "$mode" = ok ] && [ $rc -ne 0 ]; then good=0; fi
  if [ "$mode" = err ] && [ $rc -eq 0 ]; then good=0; fi
  if [ -n "$want" ] && ! grep -Eq -- "$want" "$out"; then good=0; fi
  local detail=""
  if [ -n "$show" ]; then detail=$(grep -E -- "$show" "$out" | tail -1 | sed 's/^[[:space:]]*//' | cut -c1-110); fi
  if [ $good = 1 ]; then
    printf '        PASS (%ss) %s\n' $((SECONDS - t0)) "$detail"
  else
    failed=$((failed + 1))
    printf '        FAIL (%ss, exit %s); last lines of %s:\n' $((SECONDS - t0)) "$rc" "$out"
    tail -6 "$out" | sed 's/^/          /'
  fi
}

echo "Loop 12 smoke: $(git log --oneline -1)"
rm -f cpp/build/packbin_tests   # a host build of the C++ tests confuses the Linux container, and the reverse

step "Docker CI suite: csharp"     ok "Total tests" "Passed:[[:space:]]+[0-9]+" -- docker compose -f docker-compose.test.yml run --rm csharp
step "Docker CI suite: typescript" ok "ℹ fail 0" "ℹ pass [0-9]+" -- docker compose -f docker-compose.test.yml run --rm typescript
step "Docker CI suite: python"     ok "[0-9]+ passed" "[0-9]+ passed" -- docker compose -f docker-compose.test.yml run --rm python
step "Docker CI suite: rust"       ok "test result: ok" "rust total passed" -- bash -c 'set -o pipefail; docker compose -f docker-compose.test.yml run --rm rust 2>&1 | awk "{print} /^test result: ok/ {s+=\$4} END {print \"rust total passed: \" s}"'
step "Docker CI suite: cpp"        ok "all tests passed" "all tests passed" -- docker compose -f docker-compose.test.yml run --rm cpp
step "Docker CI suite: java"       ok "All session tests passed" "All session tests passed" -- docker compose -f docker-compose.test.yml run --rm java
rm -f cpp/build/packbin_tests

step "Cross-language rings (boolflag 0100, booltrue 0101, bitwhen 010001)" ok "language pairs passed" "language pairs passed" -- bash .github/workflows/language-pair.sh
step "Python: bool outside flags refused at build (AZ-2083)" err "bool is allowed only as a direct child of flags" "ValueError" -- env PYTHONPATH=python/src python3 -c "from packbin import Scheme, u8, bool as b; Scheme(1, dict, u8(0, lambda r: r['a']), b(1, lambda r: r['on']))"
step "Python: ninth flags child refused (AZ-2083)" err "one flags byte holds 8 bits" "ValueError" -- env PYTHONPATH=python/src python3 -c "from packbin import flags, u8; flags(0, *[u8(i, lambda r, i=i: r[f'f{i}']) for i in range(9)])"
step "TypeScript: new Scheme checks + bool rule (AZ-2080, AZ-2129)" ok "ℹ fail 0" "ℹ pass [0-9]+" -- bash -c 'cd typescript && node --test --test-reporter=spec tests/scheme-constructor.test.ts tests/bool-flag.test.ts'
step "C#: bool rule, empty groups, set-group values (AZ-2079, AZ-2130)" ok "Passed!" "Passed!.*Total" -- env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo --filter "FullyQualifiedName~BoolFlagRule|FullyQualifiedName~EmptyGroup|FullyQualifiedName~FlagGroupValue"
step "Rust: flag bits, nested rounds, map pack/unpack (AZ-2082, AZ-2133)" ok "test result: ok" "test result: ok\. [0-9]+ passed" -- cargo test --manifest-path rust/Cargo.toml --lib -- round_tests flag_bits flag_presence
step "Java: references, rounds, empty groups (AZ-2089, AZ-2131)" ok "All session tests passed" "All session tests passed" -- bash -c 'out=$(bash java/test.sh 2>&1); echo "$out"; ! grep -q FAIL <<<"$out"'
step "C++: member-less empty group refused (AZ-2147)" ok "empty_group_without_member.cpp rejected" "all tests passed" -- make -C cpp test
rm -f cpp/build/packbin_tests
step "Embedded toolchain cache kept at .cache/embedded" ok "arduino-data" "platformio" -- ls .cache/embedded

printf '\n==== %d/%d steps passed ====\n' $((total - failed)) "$total"
echo "Read yourself: README 'Untrusted input' section; Jira AZ-2079..2083, 2089, 2129..2133, 2147 In Testing."
echo "Logs: $logs"
[ $failed -eq 0 ]
SMOKE
```

## Perform these checks in a terminal at the repo root

- [ ] All six CI suites pass in Docker, the same jobs GitHub Actions runs (about 1 minute with warm caches):
      `for l in csharp typescript python rust cpp java; do docker compose -f docker-compose.test.yml run --rm $l || break; done`
      (AZ-2079, 2080, 2082, 2083, 2089, 2129..2133, 2147)
- [ ] The cross-language rings agree on the bool bytes: `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) bash .github/workflows/language-pair.sh` ends with "language pairs passed" — `boolflag` (`{on:false}` → `0100`) and `booltrue` (`0101`) across all six languages, `bitwhen` (`010001`) across C#, TypeScript, Rust, Java and C++. (project AC-3, AC-4)
- [ ] A bool outside flags is refused when the scheme is built: `PYTHONPATH=python/src python3 -c "from packbin import Scheme, u8, bool as b; Scheme(1, dict, u8(0, lambda r: r['a']), b(1, lambda r: r['on']))"` ends with `ValueError: field id 1: bool is allowed only as a direct child of flags or a flag-byte bit`. (AZ-2083)
- [ ] A ninth flag bit is refused: `PYTHONPATH=python/src python3 -c "from packbin import flags, u8; flags(0, *[u8(i, lambda r, i=i: r[f'f{i}']) for i in range(9)])"` ends with `ValueError: flags 0 has 9 children; one flags byte holds 8 bits`. (AZ-2083)
- [ ] TypeScript `new Scheme(...)` refuses what `scheme(...)` refuses: `cd typescript && node --test --test-reporter=spec tests/scheme-constructor.test.ts tests/bool-flag.test.ts` → 13 pass, 0 fail. (AZ-2080, AZ-2129)
- [ ] C# bool rule, empty groups and set-group values: `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --filter "FullyQualifiedName~BoolFlagRule|FullyQualifiedName~EmptyGroup|FullyQualifiedName~FlagGroupValue"` → 46 passed. (AZ-2079, AZ-2130)
- [ ] Rust flag bits, nested rounds and the public map API: `cargo test --manifest-path rust/Cargo.toml --lib -- round_tests flag_bits flag_presence` → 45 passed. (AZ-2082, AZ-2133)
- [ ] Java references, rounds and empty groups: `bash java/test.sh` prints no `FAIL` line. (AZ-2089, AZ-2131)
- [ ] C++ refuses a member-less empty group: `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) make -C cpp test` prints `compile-fail: tests/compile-fail/empty_group_without_member.cpp rejected` and `all tests passed`. (AZ-2147)
- [ ] The embedded toolchain cache survives: `ls .cache/embedded` shows `arduino-data arduino-downloads bin platformio`; a second `docker compose -f docker-compose.test.yml run --rm cpp-embedded-esp` prints "Platform esp32:esp32@3.3.12 already installed" (no download). The Pico example fails on this arm64 Mac (known; CI x86_64 runs it).
- [ ] README "Untrusted input" (near the end) reads right to you: the three build-time rules (split bit scope, Rust/Java references, the bool rule) and the upgrade notes for `bool false`, refused shapes, C# set-group values, TypeScript `new Scheme`, Java round lists, Rust public `pack` / `unpack`.
- [ ] Jira: AZ-2079, 2080, 2082, 2083, 2089, 2129..2133 and 2147 are In Testing; AZ-2126, 2127, 2128, 2134, 2135 are open follow-ups under AZ-2069.

## Notes

No credentials needed. Docker must be running. After PASS the loop record is written, `dev` is pushed to origin, and `origin/stage` is fast-forwarded to it (`loop_end_merge: stage`). No tag is created, so nothing is published.

## Agent walk

No browser walk: no UI. Each command above was run by the agent on 2026-10-05 15:18 and passed: Python construction errors as quoted; TypeScript 13/13; C# 46/46; Rust 45 passed; Java 0 `FAIL` lines; C++ all tests passed with the new compile-fail case rejected; the six Docker suites, `language-pair.sh` (all rings), the embedded ARM stage and the ESP stage (ESP32-S3, ESP32-C3, ESP-IDF example, Arduino example; Pico not runnable on arm64) passed earlier in Run Tests (`_docs/03_implementation/test_run_loop12_report.md`).

## Result

smoke: PASS (owner, 2026-10-05), after running the one-paste script (agent trial run 15/15 at 15:23). No browser walk: no UI.
