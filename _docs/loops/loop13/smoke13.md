# Loop 13 smoke — proposed checks

LOCAL_URL: none (libraries; no UI, no local server, no local deploy script: `_docs/04_deploy/deploy_scripts.md` has no `scripts/deploy.sh` by design)
Branch: dev (no worktree, same as loops 11 and 12)
HEAD: fb9e34c (code and tests), later changes touch `README.md`, `fixtures/hostile/README.md` and `_docs/` only

## One-paste script

Paste into a terminal (zsh or bash). It runs every check below in order, prints PASS / FAIL per step with its time and a one-line result, shows the last lines of a failing step, and ends with `N/17 steps passed`. About 5 minutes with warm caches. Docker must be running. Agent trial run 2026-10-06 00:13: 17/17 passed (about 3.5 minutes).

```bash
bash <<'SMOKE'
cd /Users/zxsanny/dev/zxsanny/packbin || exit 1
export PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"
IDX="file://$PWD/typescript/src/index.ts"
logs=$(mktemp -d); n=0; failed=0; total=17
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

echo "Loop 13 smoke: $(git log --oneline -1)"
rm -f cpp/build/packbin_tests   # a host build of the C++ tests confuses the Linux container, and the reverse

step "Docker CI suite: csharp (390 tests)"     ok "Total tests" "Passed:[[:space:]]+[0-9]+" -- docker compose -f docker-compose.test.yml run --rm csharp
step "Docker CI suite: typescript (241 tests)" ok "ℹ fail 0" "ℹ pass [0-9]+" -- docker compose -f docker-compose.test.yml run --rm typescript
step "Docker CI suite: python (103 tests)"     ok "[0-9]+ passed" "[0-9]+ passed" -- docker compose -f docker-compose.test.yml run --rm python
step "Docker CI suite: rust (217 tests)"       ok "test result: ok" "rust total passed" -- bash -c 'set -o pipefail; docker compose -f docker-compose.test.yml run --rm rust 2>&1 | awk "{print} /^test result: ok/ {s+=\$4} END {print \"rust total passed: \" s}"'
step "Docker CI suite: cpp"                    ok "all tests passed" "all tests passed" -- docker compose -f docker-compose.test.yml run --rm cpp
step "Docker CI suite: java"                   ok "All session tests passed" "All session tests passed" -- docker compose -f docker-compose.test.yml run --rm java
rm -f cpp/build/packbin_tests

step "Cross-language rings incl. roundflags 01030102020303 and roundwhen 01010902 (AZ-2179)" ok "language pairs passed" "language pairs passed" -- bash .github/workflows/language-pair.sh
step "Scaffold: hostile case file and report columns" ok "hostile case tests passed" "case tests passed" -- bash -c 'bash fixtures/hostile/cases.test.sh && bash .github/workflows/report-row.test.sh'
step "TypeScript: strict typecheck of src/index.ts" ok "" "" -- bash -c 'cd typescript && npx tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts'
step "TypeScript pack refuses an out-of-range number (AZ-2084)" ok "RangeError: n: 300 does not fit in u8" "RangeError" -- node --input-type=module -e "import { BinaryPacker, scheme, u8 } from '$IDX'; try { BinaryPacker.pack(scheme(1, u8(0, r => r.n)), { n: 300 }); console.log('NO ERROR') } catch (e) { console.log(e.name + ': ' + e.message) }"
step "TypeScript repeat(k, when(k == 1, v)) packs 01010902 and unpacks aligned (AZ-2091)" ok "packs 01010902" "unpack ok" -- node --input-type=module -e "import { BinaryPacker, scheme, u8, repeat, when, eq } from '$IDX'; const s = scheme(1, repeat(0, [u8(0, r => r.k), when(1, eq(0, 1), [u8(1, r => r.v)])])); const b = BinaryPacker.pack(s, { k: [1, 2], v: [9] }); console.log('packs', Buffer.from(b).toString('hex')); let got; const r = BinaryPacker.unpack(b, s.on(row => { got = row })); console.log('unpack ok=' + r.ok + ' k=' + JSON.stringify(got.k) + ' v=' + JSON.stringify(got.v))"
step "TypeScript refuses a repeat inside a repeat round at construction (AZ-2177)" ok "a round cannot hold another repeat or times" "RangeError" -- node --input-type=module -e "import { scheme, u8, repeat } from '$IDX'; try { scheme(1, repeat(0, [u8(0, r => r.k), repeat(1, [u8(1, r => r.v)])])); console.log('NO ERROR') } catch (e) { console.log(e.name + ': ' + e.message) }"
step "TypeScript: range, scope, groups, nested rounds, round values (AZ-2084, 2090, 2091, 2177)" ok "ℹ fail 0" "ℹ pass [0-9]+" -- bash -c 'cd typescript && node --test --test-reporter=spec tests/int-range.test.ts tests/reference-scope.test.ts tests/nested-group.test.ts tests/nested-round.test.ts tests/round-values.test.ts tests/round-roundtrip.test.ts'
step "C#: reference scope, round values, loud pack, written when, nested rounds (AZ-2087, 2088, 2175, 2176)" ok "Passed!" "Passed!.*Total" -- env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo --filter "FullyQualifiedName~ReferenceScopeTests|FullyQualifiedName~RoundValueTests|FullyQualifiedName~LoudPackTests|FullyQualifiedName~SchemeOwnershipTests|FullyQualifiedName~FloatWhenTests|FullyQualifiedName~Written|FullyQualifiedName~NestedRoundTests"
step "Rust: typed integrity, typed times, stale rounds, bound names (AZ-2085, 2086, 2178)" ok "test result: ok" "rust total passed" -- bash -c 'set -o pipefail; { cargo test --manifest-path rust/Cargo.toml --lib -- integrity_tests times_tests times_stale_tests; cargo test --manifest-path rust/Cargo.toml --test times_tests --test times_names_tests --test times_route_tests --test times_shapes_tests --test bound_names_tests; } 2>&1 | awk "{print} /^test result: ok/ {s+=\$4} END {print \"rust total passed: \" s}"'
step "Publish gate (no tag is pushed, nothing is published)" ok "publish gate tests passed" "publish gate tests passed" -- bash .github/workflows/publish-gate.test.sh
step "README carries the loop 13 upgrade notes" ok "4" "^[0-9]+$" -- bash -c 'grep -c -E "^(Rust .times. and .when. changed|TypeScript pack throws where it used to write wrong bytes|C# pack no longer drops data|Reference scope is now checked)" README.md'

printf '\n==== %d/%d steps passed ====\n' $((total - failed)) "$total"
echo "Read yourself: README 'Untrusted input' (the upgrade notes and 'Limits to keep in mind'); _docs/05_security/security_report.md (F10); Jira AZ-2084..2088, 2090, 2091, 2175..2179 In Testing."
echo "Logs: $logs"
[ $failed -eq 0 ]
SMOKE
```

## Perform these checks in a terminal at the repo root

- [ ] All six CI suites pass in Docker, the same jobs GitHub Actions runs (about 1 minute with warm caches): `for l in csharp typescript python rust cpp java; do docker compose -f docker-compose.test.yml run --rm $l || break; done` (C# 390, TypeScript 241, Python 103, Rust 217). (all twelve tasks)
- [ ] The cross-language rings agree, including the two new ones: `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) bash .github/workflows/language-pair.sh` ends with "language pairs passed". `roundflags` is `01030102020303`, `roundwhen` is `01010902`. (AZ-2179)
- [ ] The scaffold checks and the strict typecheck pass: `bash fixtures/hostile/cases.test.sh && bash .github/workflows/report-row.test.sh`; `cd typescript && npx tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts` prints nothing. (CI has no typecheck job yet.)
- [ ] TypeScript pack refuses an integer out of range: packing `{ n: 300 }` into `u8` throws `RangeError: n: 300 does not fit in u8`; it used to write `2c`. (AZ-2084)
- [ ] TypeScript packs `repeat(k, when(k == 1, v))` with `{k: [1, 2], v: [9]}` as `01010902` and unpacks `k = [1,2]`, `v = [9, undefined]`. (AZ-2091)
- [ ] TypeScript refuses a `repeat` inside a `repeat` round when the scheme is built: `RangeError: repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times`. (AZ-2177)
- [ ] The new TypeScript tests pass: 130 tests in six files. (AZ-2084, 2090, 2091, 2177)
- [ ] The new C# tests pass: 182 tests in nine classes. (AZ-2087, 2088, 2175, 2176)
- [ ] The new Rust tests pass: 42 library tests and 35 integration tests. (AZ-2085, 2086, 2178)
- [ ] The publish gate test passes (about 90 seconds); it creates no tag and publishes nothing.
- [ ] README: the four loop 13 upgrade notes exist (Rust `times` and `when`, TypeScript pack errors, C# pack no longer drops data, reference scope), and "Limits to keep in mind" gives the unpack memory figures (TypeScript about 400 MB, C# about 530 MB, Java about 570 MB, Rust about 310 MB and about 1.4 GB with eight set flag bits, for a 1 MiB packet).
- [ ] Security: `_docs/05_security/security_report.md` says PASS_WITH_WARNINGS with F10 (Medium, unpack amplification of rounds) and F11 (Low). F10 and F11 have no ticket yet; say if you want them.
- [ ] Jira: AZ-2084, 2085, 2086, 2087, 2088, 2090, 2091, 2175, 2176, 2177, 2178 and 2179 are In Testing; AZ-2197 is a To Do follow-up under AZ-2069.

## Notes

No credentials needed. Docker must be running. After PASS the loop record is written, one loop-close commit is made, `dev` is pushed to origin, and `origin/stage` is fast-forwarded to it (`loop_end_merge: stage`, as in loop 12). No tag is created, so nothing is published: the v0.2.2 tag (plan13 `## Release`) needs your separate confirmation with the exact commit.

## Agent walk

No browser walk: no UI.

## Result

smoke: PASS (owner, 2026-10-06), after the one-paste script (agent trial run 17/17). No browser walk: no UI.
