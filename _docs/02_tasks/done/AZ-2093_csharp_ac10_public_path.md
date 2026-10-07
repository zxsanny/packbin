# C# AC-10 throughput test times the public typed path

**Task**: AZ-2093_csharp_ac10_public_path
**Name**: C# honest AC-10 test
**Description**: The C# 100 000 round-trip test measures `Pack(scheme, row)` + `Unpack(bytes, scheme.On(...))`, the path callers use.
**Complexity**: 1 point
**Dependencies**: AZ-2092_csharp_scoped_binding (removes per-call reflection; without it this test is expected to be close to or over the bound in CI)
**Component**: csharp
**Tracker**: AZ-2093
**Epic**: AZ-2069

## Problem

Project AC-10: "In C#, TypeScript, Rust, Java, and C++, 100000 pack-then-unpack round trips of the AC-1 fixture finish in ≤ 1 second on one core." The C# test does not measure what a C# caller runs:

- `csharp/tests/PackbinTests.cs:151-166` `Nfr_RoundTripsWithinOneSecond` calls `BinaryPacker.Pack(Target, Position)`, where `Position` is a `Dictionary<string, object?>` (`:29-35`). It then calls the **internal** `BinaryPacker.Read(Target, bytes)` (`Packbin.cs:157-165`, reached through `InternalsVisibleTo`) and reads `got.Values["Lat"]`.
- That path skips `ObjectValues.From` (row → dictionary, reflection on every call, `ObjectValues.cs:22-50,121-145`), handler dispatch (`Packbin.cs:134-155`, `SchemeHandler<T>.Dispatch` `:44-51`) and `ObjectValues.To<T>` (dictionary → row, `:30-73`).
- Probe (copy of sources at `d108141`, M-series Mac, 100 000 round trips of the golden position row):

| Path | Release | Debug |
|---|---|---|
| Dictionary + internal `Read` (what the test times) | 81 ms | 195 ms |
| Typed `Pack(scheme, row)` + `Unpack(bytes, scheme.On(...))` (public API) | **719 ms** | **933 ms** |

- CI runs `dotnet test` (Debug) in a container (`.github/workflows/run-suite.sh:25`) on slower hosts. The public path is at 93 % of the budget on a fast laptop and is never measured.
- Rule "real results, not simulated ones": a passing test that skips the real pipeline is worse than a failing one.

Cross-language: the Java AC-10 test already times the public typed path (`PackbinTest.java:219-241`: `BinaryPacker.pack(TARGET, position())` + `unpack(bytes, TARGET.on(...))`).

## Outcome

- The AC-10 test builds a `PositionRow` object and runs `BinaryPacker.Pack(scheme, row)` and `BinaryPacker.Unpack(bytes, scheme.On(r => got = r))` 100 000 times. It asserts every row round-trips (`Lat == 500_000_000`) and the elapsed time is ≤ 1 s.
- The test names the path it measures, so a later refactor cannot silently swap it back to the internal path.

## Scope

### Included
- `PackbinTests.Nfr_RoundTripsWithinOneSecond` rewritten to the public typed API, using the existing `PositionRow` and `Target` scheme (`PackbinTests.cs:19-48`).
- Keep `AssertNoGpuLibrary`.

### Excluded
- Making the path faster. That is task 23. If this test fails in CI before task 23 lands, the fix is task 23, **not** a looser bound or a different path.
- Other languages' AC-10 tests.

## Acceptance Criteria

**AC-1: Public path is measured**
Given the golden position row as a `PositionRow` object and the `Target` scheme
When the AC-10 test runs
Then it calls only public API (`BinaryPacker.Pack(Scheme<T>, T)` and `BinaryPacker.Unpack(ReadOnlySpan<byte>, SchemeHandler[])`) inside the timed loop, with no `Read` and no dictionary.

**AC-2: Correctness inside the loop**
Given each iteration
When unpack returns
Then the error is `null`, the handler ran, and `Lat == 500_000_000`.

**AC-3: Bound**
Given the CI container (`docker compose -f docker-compose.test.yml run --rm csharp`)
When the suite runs
Then the elapsed time is ≤ 1.0 s (project AC-10), and the message reports the milliseconds.

## Non-Functional Requirements

**Performance**
- The bound stays at exactly 1.0 s (AC-10). No warm-up loop outside the timed section beyond one call.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `Nfr_RoundTripsWithinOneSecond` uses `Pack(Target, row)` + `Unpack(bytes, Target.On(...))` | compiles without `InternalsVisibleTo` for this test |
| AC-2 | per-iteration assertion on `Lat` and `err == null` | passes |
| AC-3 | elapsed ≤ 1.0 s in the CI container | passes after task 23; if it fails earlier, keep it failing and fix through task 23 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `fixtures/golden.hex` position row | 100 000 public round trips in the CI C# container | ≤ 1 s, 0 errors | AC-10 |

## Constraints

- Test only; no production code change.
- The golden hex stays `4001000065cd1d00a3e1110100` (the existing `Ac1_PositionPack` keeps checking it).

## Risks & Mitigation

**Risk 1: The suite turns red before task 23**
- *Risk*: the public path may exceed 1 s in CI.
- *Mitigation*: land this test together with or after task 23 (dependency above). A red result is correct information, not a reason to change the measured path.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| If task 23 slips, the honest test may fail CI on a slow runner. Do not relax the bound or revert to the dictionary path to get green. | meta-rule "real results" | accepted-risk | Medium |

## Loop 17 result (2026-10-07)

Done in batch 1 (commit `0f60607`). `Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` times only `BinaryPacker.Pack(Target, row)` and `Unpack(bytes, Target.On(...))`, asserts `Lat == 500_000_000` and a null error per iteration, bound 1.0 s, best of three passes as before; 274 to 284 ms per pass in Debug after AZ-2092 (791 ms before).
