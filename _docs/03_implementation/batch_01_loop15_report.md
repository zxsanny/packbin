# Batch Report

**Batch**: 1 (loop 15)
**Tasks**: AZ-2214_ci_pin_credentialed_job, AZ-2216_csharp_round_limits, AZ-2217_typescript_round_limits, AZ-2218_java_round_limits
**Date**: 2026-10-06

Four workers in parallel on disjoint paths (`.github/` + `cpp/embedded/examples.sh`, `csharp/`, `typescript/`, `java/`). Parent re-verified the whole tree after the workers finished.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2214_ci_pin_credentialed_job | Done (AC-1 to AC-8) | 3 new (`tool-pins.txt`, `tool-pin.sh`, `publish-pins.test.sh`), 9 modified (`publish.yml`, `test.yml`, `publish-lib.sh`, `publish-inside.sh`, `run-suite.sh`, `publish-gate.test.sh`, `publish-phases.test.sh` one line, `cpp/embedded/examples.sh`, `ci_cd_pipeline.md`) | `publish-gate.test.sh` passes with the new `pins_checks`; 13 violating temp copies of the `uses:` check rejected | 3 registry-side items only the first real tag proves |
| AZ-2216_csharp_round_limits | Done (AC-1 to AC-11) | `Packbin.cs`, `Scope.cs`, `Walker.cs`, `Walker.Counted.cs`, `Walker.Rounds.cs`, new `tests/RoundLimitTests.cs` | 407 of 407 (390 before, +17) | 1 load-sensitive NFR test failed twice at 1.1 s under load average 30+, passes otherwise |
| AZ-2217_typescript_round_limits | Done (AC-1 to AC-11) | `index.ts`, `kinds.ts`, `walker.ts`, new `tests/round-limits.test.ts` | 276 of 276 (241 before, +35); strict `tsc` exit 0 | none |
| AZ-2218_java_round_limits | Done (AC-1 to AC-11) | `Scheme.java`, new `Cursor.java`, `Rounds.java`, `Walker.java`, `VarFields.java`, `Containers.java`, `BinaryPacker.java`, new `RoundLimitsTest.java`, one line in `PackbinTest.java` | all four runners and `api-check` pass | none |

No existing test, hostile vector or ring was edited in any package.

## Decisions

- **Limits live on the scheme (D1), checked when a round starts (D5, lazy).** Defaults 65,535 rounds and 4,194,304 slots per unpack call. Refusal uses each package's interim bad-value error (`ShortPacket(label, 0, left)` shape); no handler call, no partial row.
- **C#**: `Scheme<T>.WithLimits(maxRounds = 65,535, maxSlots = 4,194,304)` returns a new scheme (an omitted limit is the default, not the receiver's value); `MaxRounds`, `MaxSlots`, `BinaryPacker.DefaultMax*`; internal `RoundBudget` carried by every scope of a call.
- **TypeScript**: `scheme.withLimits({ maxRounds?, maxSlots? })`, `Scheme.DefaultMax*`, `RangeError` for a limit that is not a positive safe integer, counters on `ViewCursor`. An optional third constructor parameter and the exported `SchemeLimits` type were added (not in the spec's surface list).
- **Java**: `scheme.withLimits(int, long)`, `Scheme.DEFAULT_MAX_*`, `IllegalArgumentException`; a package-private `Cursor` replaces `int[] offset` in every unpack method (mechanical rename, the compiler found every site).
- **AZ-2214**: one pins file `tool-pins.txt` (`npm==11.21.0`, `twine==7.0.0`, `platformio==6.2.0`, `idf-component-manager==3.1.2`, `build==1.6.1`, `setuptools==84.0.0`, `pytest==9.1.1`) read by `tool-pin.sh`; `pip_install_pinned` installs wheels only (`--only-binary=:all:`); `PIP_CONSTRAINT` holds setuptools in the isolated Python build; the five `uses:` lines are pinned to commits (`actions/checkout` `3d3c42e5…` v7.0.1, `actions/setup-node` `82076278…` v7.0.0, `NuGet/login` `8d196754…` v1.2.0, the peeled commit); the `uses:` check is a new Ruby function in `publish-pins.test.sh` that fails on any non-local `uses:` that is not a 40-hex commit with a tag comment.

## Memory (1 MiB of one-byte rounds, audit's 36-name body)

| Package | Before | After (defaults) |
|---------|--------|------------------|
| C# | 2,704 MiB allocated, 569 MiB peak working set, 3.4 s | 169.5 MiB allocated, 129 MiB, 0.23 s, refused |
| TypeScript | 400 to 403 MB peak RSS, about 220 ms | 85 to 86 MB, about 12 ms, refused |
| Java | 520 to 566 MB peak heap, about 800 ms | 34 MB, 90 to 116 ms, refused |

## Code Review Verdict: PASS_WITH_WARNINGS

Parent read every hunk and ran `/code-review` high over the whole tree. Mutation checks by the workers: removing the check fails 8 (C#), 13 (TypeScript) and 25 assertions (Java), while the acceptance and API tests still pass. Findings, none blocking:

| # | Severity | Finding | Handling |
|---|----------|---------|----------|
| 1 | Low | C# `WithLimits` and TypeScript `withLimits` take the default for an omitted limit, so chaining `.WithLimits(maxRounds: 200_000).WithLimits(maxSlots: 8_000_000)` silently drops the first | Open, as specified (AC-1). README (AZ-2220) states it |
| 2 | Low | C# allocates one `RoundBudget` per `Unpack`/`Read` even without rounds (about 7% on `Nfr_RoundTripsWithinOneSecond`, estimated) | Open, recorded |
| 3 | Low | The slot count per round differs by package (C# distinct names, TypeScript name set, Java value fields): at exactly the slot limit a packet could pass in one package and not in another for a body with a named flag byte or a repeated name | Open; the README (AZ-2220) states the count and the hostile case uses a low round limit, not a slot limit |
| 4 | Low | TypeScript `Scheme` has a public third constructor parameter; `withLimits` re-runs the constructor on already bound fields | Accepted: tested with a `sized` reference |

CI-parity: PASS. Run by the parent after the workers finished, one stage at a time: the six `docker compose -f docker-compose.test.yml run --rm <lang>` suites (C# 407, TypeScript 276, Python 103 with the pinned pytest 9.1.1, Rust 217, C++ and Java all passed), `cpp-embedded` (4 of 4 targets), `cpp-embedded-esp` (4 of 5; `cpp-example-pico` fails on this arm64 host by design, covered by CI and by the loop 14 runs with both toolchains), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh` (343 s), strict `tsc` with the AGENT_GOTCHAS flags, `language-pair.sh` (64 s, `PACKBIN_CXX_SYSROOT` set). 12 of 13 stages passed.

One process note: the AZ-2214 worker ran `git stash` and `git stash pop` once for a shellcheck baseline while three other workers were writing. The parent found the tree intact afterwards (every expected file present, empty stash list) and the later full re-run passes.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `PackbinTests.Nfr_RoundTripsWithinOneSecond` fails at about 1.1 s when the machine load average is above 30 | AZ-2216 NFR | None in this task; a looser bound or a CI note is the owner's call | unclear |
| 2 | `dotnet format --verify-no-changes` reports 48 whitespace errors in `csharp/Walker.Scalars.cs` and 3 in `csharp/tests/LayoutTests.cs` (not files of this loop) | AZ-2216 Constraints | A separate formatting task | clear |
| 3 | A C# round scope can hold keys outside `RoundNames` (a named flag byte); the slot limit counts only `RoundNames` | AZ-2216 | README line in AZ-2220 | clear |
| 4 | Round-holding list and dictionary elements still cannot be tested in C# (AZ-2119) | AZ-2216 | Add the element case when AZ-2119 lands | clear |
| 5 | The transitive pip dependencies still float, the GPG key stays visible to host-side pip installs, `PYPI_TOKEN` stays beside OIDC, `persist-credentials` is unchanged: F12 is reduced, not closed | AZ-2214 Flagged concerns | Recorded as accepted in the spec; reported in the security audit of this loop | clear |
| 6 | Only the first real tag proves `setup-node` and `NuGet/login` at the pinned commits, `npm install -g npm@11.21.0` with trusted publishing, and the pinned pip tools on the real `ubuntu-24.04` runner (Python 3.12.3) | AZ-2214 | First real tag | unclear |

## Commit

`[AZ-2214] [AZ-2216] [AZ-2217] [AZ-2218] Pin the credentialed job, limit unpack rounds`. Body: one line + `Loop: 15`.

## Next Batch: AZ-2215_build_containers_read_only, AZ-2219_rust_round_limits
