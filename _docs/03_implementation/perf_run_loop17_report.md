# Performance Run — loop 17 (C# typed path)

**Date**: 2026-10-07. **Commit**: `412ae3a`. **Host**: macOS arm64 laptop, .NET 10.0.103, Release unless stated, one process at a time (a docs worker was editing files in the repo, no builds). **Mode**: perf (`test-run`), scoped to AZ-2092 AC-7 and project AC-10 ("100 000 pack-then-unpack round trips of the AC-1 fixture finish in 1 second or less on one core").

Workload: 100 000 round trips of the position row, public typed API only: `BinaryPacker.Pack(Target, row)` then `BinaryPacker.Unpack(bytes, Target.On(...))`, error `null` and `Lat == 500_000_000` checked in every iteration. Before = an export of `68ca4f8` (the commit before the loop), after = `412ae3a`; same program, three runs each, six passes per run.

| Measure | Before (`68ca4f8`) | After (`412ae3a`) | Ratio |
|---------|--------------------|-------------------|-------|
| Standalone Release, cold first pass | 564, 566, 570 ms | 268, 266, 274 ms | 2.1x |
| Standalone Release, best warm pass | 147, 146, 146 ms | 63, 62, 63 ms | 2.3x |
| AC-10 test (`Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond`), Release, fastest of up to three passes | 641 to 656 ms (batch 1 worker) | 319, 343 ms | 2.0x |
| AC-10 test, Debug (what `dotnet test` and CI run) | 791 ms (batch 1 worker, on the export) | 346, 326 ms (274 to 284 ms measured by the worker with the machine idle) | 2.3 to 2.9x |

Designated environment (the CI container, `mcr.microsoft.com/dotnet/sdk:10.0` on Docker Desktop, Debug, the AC-10 test alone, three runs per target): net10.0 341, 378, 382 ms; the `netstandard2.0` build 337, 390, 338 ms per pass (about 2.6x under the bound).

**In the full container suite the same test is much slower**: the total test run logged 786 ms for the test on net10.0 and "1 s" on the `netstandard2.0` run (the xunit duration of the whole test; a pass above 1.0 s is retried, the best of up to three passes counts). The cause is xunit running test classes in parallel: `PackbinTests` has no `[Collection]` with `DisableParallelization`, so the timing test competes with every other class for the cores. Isolated it is 340 to 390 ms; under suite load it used 790 ms to 1 s, a margin of 1.0x to 1.3x, and the retry is what keeps it green. A slower CI runner can turn that red. Follow-up review R3 (done after the CI failure below): the timing test now runs in a collection with `DisableParallelization = true` and the bound is a single strict pass, as AZ-2093 asks.

**CI result (GitHub Actions, ubuntu runner, run 37588554503 at `87e554f`, Debug, inside the full suite): the test FAILED with `fastest of the passes: 1617.9208 ms`** (bound 1000 ms; all up to three passes were over it). The runner is much slower than the Apple-silicon laptop and the pass competed with the parallel suite. Fix (this loop, after the first push): the test moved to its own class in a xunit collection with `DisableParallelization = true` (`csharp/tests/Ac10TimingTests.cs`), one call before the timer, one timed pass, bound still 1000 ms, no retry. In the CI container image on the Mac, inside the whole suite, it now takes 379 ms on net10.0 and 445 ms on the `netstandard2.0` build (786 ms and about 1 s before). After the fix `test.yml` is green on `dev` and `main` at `f0f67ce` (the C# suite passed on the runner; its per-test time was not read: the log page of a green job renders only its first lines and the test prints its time only through the output helper). The runner's isolated figure therefore stays unknown; if the test turns red again the options are the owner's (typed walker, assessment D11), never a looser bound.

## Verdict

- **Project AC-10: PASS, with a thin margin under suite load.** The bound is 1.0 s for 100 000 round trips on the public typed path (the AZ-2093 outcome). Isolated, the slowest pass is 390 ms (container) and 346 ms (laptop), about 2.6x to 2.9x under the bound; inside the full container suite the test used 786 ms on net10.0 and about 1 s on the `netstandard2.0` run, so on a slower runner it relies on the retry (review R3).
- **AZ-2092 AC-7: partly met.** The target "at least 3x faster, at most 300 ms Release for 100 000 on the reference Mac": the cold standalone pass is 266 to 274 ms (target met), the warm pass is 62 to 63 ms, the speed-up is 2.1x cold and 2.3x warm (3x not met), and the Release test run is 319 to 343 ms (300 ms missed by a little). The engine alone (dictionary pack and read) costs about 130 ms cold; going lower needs a typed walker that does not go through a dictionary, which the owner decides (assessment D11, review R2).
- No regression anywhere: the dictionary path (`Pack(scheme, IReadOnlyDictionary)`) was not changed by the loop except the stricter number checks of AZ-2191 (the batch 2 worker saw the Debug AC-10 pass move from 283 to 308 ms, within noise).

Memory (batch 1 worker, not repeated): a 1 MiB packet of 16 lists x 65 535 one-byte elements allocates 285 MB typed (276 MB before, +3%); with row-typed elements 327 MB. See F10 in `_docs/05_security/security_report.md`.
