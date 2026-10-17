# Test run report — loop 34 (AZ-2627, CI speed 5)

TEST RESULTS: 11 stages passed, 0 failed at the end (scaffold failed once in the pool and passed on the serial retry after a fix; see below)
SUITE: specified 13 / executed 11 / not-run 2 (`cpp-embedded-arm` and `ac10` unchanged since 6249fdc and 8d4f1a8, skipped by the stamp rule; the eight language suites ran because `run-suite.sh` changed)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks (`NOT RUN: vcpkg supports check, vcpkg consumer check`), no vcpkg tool on this host; the CI `publish-gate-rest` job runs them.

## Step 11 (commit 7daf8c4 plus the `report-row.test.sh` fix, Mac arm64, `scripts/loop-tests.sh`, about 1 080 s, load 5 to 52, swap 9 of 10 GB at the start)

| Stage | Result | Time |
|-------|--------|------|
| typescript, csharp, python, rust, java, cpp, go | PASS | 9, 51, 62, 30, 24, 44, 128 s (pool of 3) |
| swift | PASS | 360 s (the whole suite in one run, as on the Mac: no `PACKBIN_SWIFT_CACHE`, so no ccache and no kept output, AC-9) |
| scaffold | FAIL in the pool (1 s), PASS on the serial retry (239 s) | `report-row.test.sh` read each matrix entry's `lang` as one language: `csharp rust` was not `csharp`. Fixed (split on spaces) while the pool ran, before the gate stage; the retry ran the fixed file |
| ring | PASS | 60 s |
| publish-gate | PASS | 322 s: `phases` 314, `phases-rerun` 321, `readonly,gate` 244, `readonly-gate-good` 212, `-bad` 219, `-nojava` 215, the rest 298, `swift` 200 s; tree unchanged (1 740 paths) |

The scaffold miss is a process gap: before the batch commit I ran the guards I had changed, not the whole scaffold list; `report-row.test.sh` also reads the `suites` matrix. CI's `scaffold` job would have failed the same way on the first push.

## Before step 11 (batch and review fixes)

- Guards: `publish-jobs.test.sh` (24 new mutants), `ring-wiring-swift.test.sh` (8 new mutants, one behaviour row), `run-suite.test.sh` with `run-suite-swift.test.sh` S12a to S12g, `ring-prepare.test.sh` (row 1b, 6 mutants), `ring-wiring.test.sh`, `scripts/loop-tests.test.sh`, `publish-gate.test.sh --groups workflow,static`: PASS.
- Mutants of the new code in scratch copies: 11 of 12 rejected, the twelfth equivalent (batch report, review record).
- Real runs in `swift:6.3.3` on the Mac: the `tests` part through compose with CI's mounts, miss then hit (372 of 372 ccache hits, debug build 52 s then 9 s); `swift-ccache.sh run` as uid 1001 (3 misses, then 3 hits after a restore; directories owned by the caller).

## After batch 2 (ccache removed, 2026-10-17)

`scripts/loop-tests.sh --only scaffold,ring`: scaffold PASS 239 s, ring PASS 60 s; `publish-jobs.test.sh` and `publish-gate.test.sh --groups workflow,static` PASS. The language suites were not re-run on the Mac: `run-suite.sh` changed only its CI-only cache line (S12, two mutants); CI runs every suite on runs B and C.
