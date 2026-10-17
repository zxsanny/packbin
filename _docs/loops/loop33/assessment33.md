# Feature assessment — loop 33

loop: 33
feature: ci-speed-4
rounds: 1
verdict: COMPLETE (every AC has code, a guard or test and a production path; AC-2 measured 209 s against 180 s, a miss the owner accepted on 2026-10-17; AC-1 run 1 251 s, run 2 at the close push)

FEATURE ASSESSMENT loop 33 round 1: COMPLETE — 12 covered / 1 accepted miss / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | scenario | status | evidence |
|----|----------|--------|----------|
| AC-1 | CI wall, median of two `dev` runs at most 250 s | covered (run 2 at the close push) | run 39031026351 (`19f4c33`): 251 s, 23 of 23 green, the wall is `suites (swift, tests)` 248 s; run 2 in `notes33.md` |
| AC-2 | `ring` at most 180 s on both runs; the ring unchanged | missed, accepted by the owner | 209 s (was 255 to 273 s): the swift pull (68 s, slowed by the parallel gcc pull) plus the Swift driver build (84 s) are the path; `language-pair.sh` unchanged (ring step 39 s); owner 2026-10-17: accept, C3 next loop |
| AC-3 | pulls and Swift build in the background from the first step, npm/cargo/Go at once, all toolchains checked before the ring | covered | `test.yml` `ring`; `ring-prepare.sh start/build`; test: start returns before the swift pull ends, the Swift build begins after it, both pulls and all three builds overlap (order of the stand-ins' lines); `ring-wiring.test.sh` (toolchains before the ring, Go build, `RING_GCC` used by the start line); real run on the Mac |
| AC-4 | a failed or hung build fails the wait, named, with its log; bounded | covered | `failures` + bounded wait (900 s, whole seconds, never early); test: swift build, gcc pull, swift pull (build skipped), cargo fail; a hang under a 2 s limit; 5 mutants of the script |
| AC-5 | one timing notice | covered | run 39031026351: one `ring preparation timing` notice with the six builds and the wait; `wait` writes one `ring preparation timing` notice on GitHub Actions only; test checks one notice with the build lines and the wait line, and none outside Actions |
| AC-6 | Swift wiring in `scaffold` only | covered | `ring-wiring-swift.test.sh` rule + mutants w4, w5, w10; `publish-jobs.test.sh` static list (scaffold only) |
| AC-7 | exact pull lists, missing/extra/duplicate refused | covered | pulls 35, 35, 51 s (were 57, about 57, 59 s); `publish-jobs.test.sh` group → images map from the code trace; 9 new mutants refused with the right message |
| AC-8 | no check lost, guards pass, a mutant per changed rule | covered | every guard named in the spec passes (batch report); each changed rule has a rejected mutant |
| AC-9 | Mac step 11 | covered (step 11 run) | `scripts/loop-tests.sh` scaffold list runs `ring-prepare.test.sh` |
| AC-10 | changed files at most 500 lines | covered | `ring-wiring.test.sh` 500, the rest 155 to 385 |
| D1 | `RING_GCC` was used only by the removed pull step | covered | the start line names its images (`"gcc:$RING_GCC" "swift:$RING_SWIFT"`) |
| D2 | a failed `build` hid the background builds (review) | covered | `wait` is the verdict for every build; build before wait, last in its step (mutant w12) |
| D3 | the wait gave up up to 1 s early (found by a repeat run) | covered | `-le` on whole seconds; the hang check demands at least the limit |
| S8 | a group that starts a new image without a map update | out-of-scope | `scenarios.md` row 8: only slower (compose pulls on first use), accepted-risk |

## Not walked

None: the scenario matrix has 8 rows; the batch report's discoveries are all `clear` and handled.
