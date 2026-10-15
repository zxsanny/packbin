# Feature assessment — loop 27 (round 1)

FEATURE ASSESSMENT loop 27 round 1: COMPLETE — 7 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (1 measurement still running, carried as a leftover)

Intent baseline: `_docs/02_task_plans/ci-publish-gate/` (`problem.md`, `acceptance_criteria.md` CG-1 to CG-8). No batch reports and no `scenarios.md`: the loop was diagnosis-first (harness gap, noted). Evidence: CI run 38694589648, the Linux container run (Swift 6.4.1), the Swift stage run (349 s), `review27.md`.

| Row | Status | Evidence |
|-----|--------|----------|
| CG-1 three jobs green | covered | run 38694589648 `success` x3; fix `publish-swift-gate.test.sh` `sw_write_ring_swift`; test `publish-swift.test.sh` position checks |
| CG-2 gate <= 1 500 s, scaffold <= 3 000 s | covered | gate 1 322 s, scaffold 2 618 s on that run |
| CG-3 gate green 3 runs in a row | pending (1 of 3) | run 38694589648 green; run 38700362252 (`00ad75f`) in progress; a time measurement, no spec or code left to add: carried as a leftover |
| CG-4 cause named | covered | `deploy_status_report.md` section "Loop 27: cause of the `aefaf37` publish gate failure" (9 failures before, 0 after, in `swift:6.4.1`) |
| CG-5 Swift stage <= 500 s, sanitizer on the threaded suites | covered | `run-suite.sh` `swift_sanitized`; tests S2, S6b (3 suites), S6c; stage 349 s, 340 tests in 56 suites plain, 27 tests in 3 suites sanitized |
| CG-6 (amended) no dead-weight speed-ups | covered | the two speed-ups not done are justified by measurement in the acceptance criteria; the Swift scenarios keep 30 of 30 mutants rejected |
| CG-7 other toolchain checks unchanged, ring < 10 min | covered | `git diff` of `ring-toolchains.sh` over the loop: 0 lines; ring 265 s |
| CG-8 no tag, no upload | covered | 0 `git tag` or publish commands run; pushes were `git push origin dev` only |

## Discovered during the loop

| Angle | Handling |
|-------|----------|
| The `f30c87e` gate failure (1 of 2 runs, before `aefaf37`) has a different, unknown cause | open flagged concern (Medium); CG-3 decides; leftover |
| Linux-only paths (`ring-swift.sh` image build, `use_local_swift` on Linux) are exercised on CI only; the Mac cannot reach them | tested in a `swift:6.4.1` Linux container this loop; no standing Mac test possible; noted |
| `scaffold` uses 43.6 of 60 minutes on the runner | the sanitizer cut saves about 5 minutes; measure on run 38700362252 |

## Not walked

None.
