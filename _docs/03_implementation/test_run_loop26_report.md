# Test Run — loop 26

**Date**: 2026-10-14
**Mode**: functional, step 11 through `scripts/loop-tests.sh` (owner decision AZ-2500): one total run for the loop, workers ran only their own suite. Three invocations because the container run found defects that were fixed between them (below). Host: Mac, 10 CPUs; load 8 to 32 while the stages compiled; no swapping (0 swapouts in 10 s before each run).

| Invocation | Commit | Stages | Result |
|------------|--------|--------|--------|
| 1 | `682fe52` | go, typescript, csharp, python, rust, java, cpp, swift, scaffold, cpp-embedded-arm, ring, publish-gate (ac10 skipped, unchanged) | 10 passed, 2 failed: `swift` (sanitizer run) and `publish-gate` (Linux driver compile) |
| 2 | `858b8c2` | swift, scaffold, ring, publish-gate (the others skipped, unchanged) | scaffold, ring, publish-gate PASS; `swift` failed on one sanitizer timing bound |
| 3 | the commit after `858b8c2` ("Sanitizer runs assert the outcome, not the one-second bound") | swift only | PASS (620 s) |

```
TEST RESULTS (step 11): 12/12 stages passed at the end; failed = 0
  go 125 s, typescript 9 s, csharp 56 s, python 136 s, rust 25 s, java 24 s, cpp 31 s FAIL in the pool then 24 s PASS alone (see below)
  swift (swift:6.3.3 container: strict release build, 335 tests debug, swift test list, 60 s fuzz, thread-sanitizer run, release speed + 1 MiB hostile unpack, dependency check) 620 s PASS
  scaffold 273 s (golden row, report-row, hostile cases 65 with eight package names, run-suite, embedded lib, ring wiring incl. ring-wiring-swift, loop-tests.test.sh)
  cpp-embedded-arm 9 s (cached), ring 72 s (all 15 kinds, Swift in every ring, session ring, position) 
  publish-gate 1837 s PASS: no failures, NOT RUN: the vcpkg supports and consumer checks (no vcpkg tool on the host)
SUITE: specified 13 / executed 12 / skipped as unchanged 1 (ac10) / not-run inside stages: vcpkg supports + consumer checks
```

## Verdict: PASS

All stages pass at the end; `failed = 0`. Not run on this host: `cpp-embedded-esp` (CI only), the vcpkg checks (no tool), Swift 6.0 (only the 6.3.3 image and the Mac's 6.3.3 compiler ran), tvOS and watchOS, the first Ubuntu runner run of the new `swift` and ring steps (CI on the `dev` push is their proof), a Swift 6.0 consumer resolve.

## Defects found by this run (all fixed in the loop)

1. **The image tag `swift:6` does not exist on Docker Hub** (`manifest unknown`); the CI image is `swift:6.3.3` (tool pin changed, compose, ring `RING_SWIFT`). Found when pulling for this run; CI would have failed at the pull.
2. **Swift 6 rejects `fputs(..., stderr)` on Linux** (`stderr` is a shared mutable global; macOS accepts it): the `position` and `handoff-swift` drivers failed to build in the publish gate's container. Fixed with `FileHandle.standardError`.
3. **The thread-sanitizer run took 25 minutes in the Linux container** (2 minutes on the Mac) and failed three 1 MiB timing bounds (15 to 28 s a packet) and one 65 535-round refusal (38 s against 1 s): the single-threaded size and speed tests (max slots 1178 s, 16 MiB, the mebibyte packets, the speed run) no longer run under the sanitizer, the one-second bounds are not asserted under it, and the debug speed test makes one pass. The bounds are held by the plain debug and release runs. The sanitizer run now ends in the 620 s stage.
4. **`pack_foundationDictionaryWithNFCAndNFDKeys_isRefusedNotMerged` is flaky on Linux** (2 of 8 runs of the same binary): Linux Foundation merges the two keys in the `NSDictionary` itself per process (hash seed), so there is nothing left to refuse. The test now requires two kept keys first.
5. **C++ failed once in the parallel pool** (`ld: cannot open output file build/packbin_tests`, right after `mkdir -p build`, at load 12): a race in the shared `cpp/build` directory under load; it passed alone in 24 s (the script's serial retry). Not a code defect; recorded for the loop 27 handoff (the pool and the host `make clean` share `cpp/build`).

## Notes

- The Linux sanitizer figures: before the fix `LimitEdgeTests` took 1508 s in total (`exactly1048576Slots` 1178 s). After: the whole `swift` stage 620 s.
- The publish gate took 1837 s (706 s in loop 25): the real-swift consumer scenario and 27 more mutants; the scaffold job's 60-minute limit and the `publish.yml` 120-minute limit (raised in the review) are the budgets to watch on the first CI run.
