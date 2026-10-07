# Intake: dev CI red since loop 17, the AC-10 test on the public typed path

kind: intake
created: 2026-10-07T10:50:00
source: poll-fail
status: pending

## Problem
The `test` workflow on `dev` at `87e554f` (run 37588554503, GitHub Actions, ubuntu runner) fails in the `scaffold` job, step `suites`: `Packbin.Tests.PackbinTests.Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` reports `fastest of the passes: 1617.9208 ms` for 100 000 public typed round trips (bound 1.0 s, AC-10), in the C# suite on net10.0; 648 of 649 tests pass. `ring` passed; `embedded` was still running when this was written. `main` was not pushed (loop end channel pushes `main` only after a green `dev`).

## Proposed outcome
`dev` and then `main` green on `test.yml` with the AC-10 test keeping the public typed path and the 1.0 s bound (AZ-2093: do not relax the bound or measure another path). Needs a decision on how the typed path gets there (owner decision 1 and 9 of `handoff18.md`).

## Affected users and systems
CI of the whole repository (every push to any branch runs `test.yml`); the C# package's AC-10 claim; loop 18's first push.

## Evidence
Run page `https://github.com/zxsanny/packbin/actions/runs/37588554503` (job 112684290214, step 8 `suites`, log line 1099 to 1101 of the step); the test is `csharp/tests/PackbinTests.cs:161-178` (best of up to three passes, all three over 1.0 s). Measured here, same test: isolated 337 to 390 ms in the CI container image on an arm64 Mac (Debug), 786 ms to about 1 s inside the full suite on the same Mac, 319 to 343 ms Release on the laptop; the standalone Release benchmark is 2.1x faster cold than before loop 17 (564 to 268 ms). The runner is therefore about 4x to 5x slower per pass than the laptop in isolation. Before loop 17 the same test on the public path would have been about 2x to 3x slower again (791 ms Debug on the laptop).

## Constraints
Do not loosen the 1.0 s bound, do not time the dictionary path or an internal method, do not re-run or retrigger CI by hand (`meta-rule`: one canonical path), do not push `main` while `dev` is red, no tag.

## Open questions
1. Options: A) make the typed path faster (a typed walker that does not go through a dictionary; the engine alone costs 130 ms cold of 570), B) run the AC-10 test in Release in CI (the library ships as Release; a configuration change, not a bound change), C) put the timing test in a non-parallel xunit collection (removes suite contention, may not be enough: the runner is slow even alone), D) amend AC-10 (owner only). Recommendation: C then B, and A when the owner wants more margin; each is a decision the owner takes (the AZ-2093 text calls a looser bound or another path the wrong fix).
2. What the CI runner's isolated per-pass time is (unknown: the log of the failed run prints only the fastest pass; the test writes one line of output).

## Replay payload
Problem: AC-10 (100 000 public typed pack and unpack round trips in at most 1 s) is red on GitHub Actions' Linux runner for the C# suite since the first push of the honest AZ-2093 test, although it passes on Apple-silicon Docker (786 ms to 1 s inside the suite, 340 to 390 ms alone). Outcome: a green `test.yml` on `dev` with the same test and bound. In scope: `csharp/tests/PackbinTests.cs` (collection), `.github/workflows/run-suite.sh` (configuration), `csharp/` typed walker (speed). Out of scope: other packages. First step: decide A to D; then fix on `dev`, run the C# suite in the CI container, push once and watch (`ci_cd_pipeline.md` § Post-deploy polling).
