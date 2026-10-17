# Loop 32 notes — CI speed 3 (AZ-2625)

## Profile of the phase scenarios (Mac, one run, scratch copy of the tree with a `prof` wrapper per function)

`publish-gate.test.sh --groups phases` on the loop 31 `phase_checks`, seconds per function (Mac, a second container job running beside it; the CI total of the group was 221 s):

| Function | s | | Function | s |
|----------|--:|-|----------|--:|
| `ph_static_checks` | 1 | | `ph_failure_injection` | 48 |
| `ph_setup` | 15 | | `ph_pipeline_violations` | 21 |
| `ph_fabricated_checks` | 1 | | `ph_rerun_checks` | **128** |
| `ph_empty_plan` | 0 | | total | 272 |
| `ph_build_only` | 30 | | | |
| `ph_full_publish` | 27 | | | |

The cut the owner suggested (success scenarios against failure scenarios) would have been 73 s against 213 s here, because the re-run and registry-policy scenarios (`ph_rerun_checks`, AZ-2097: credential matrix, re-run chain, partial python and maven, embedded failures, 7 publish runs with real builds) are 128 s on their own and are in the failure side by their nature. The cut by measured seconds: `phases` = everything but the re-run scenarios (128 s of work plus `ph_setup` 15 s) and `phases-rerun` = `ph_rerun_checks` (128 s plus `ph_setup` 15 s): 143 s against 143 s on the Mac. Owner decision D4 asked for the profile before the cut; the groups are named `phases` and `phases-rerun`, and the phase check functions are held to one group each by `ph_split` in `publish-timing.selftest.sh`.

## Changes by file

- `publish-readonly.test.sh`: `ro_gate_checks` (three gate runs at once, then the assertions) is `ro_gate_run <name> <logs>` (tree copy, manifest, one gate run, rc) plus `ro_gate_good_check`, `ro_gate_bad_check`, `ro_gate_nojava_check`, each with the assertions its scenario had. One assertion is gone with the concurrency: the bad scenario checked that its `.rc` file existed and was non-empty ("the run did not finish"); the scenario now runs in the foreground and the rc file is always written, so the check could not fail.
- `publish-gate.test.sh`: `gate_groups` 16 → 19 (`readonly-gate` out; `readonly-gate-good`, `-bad`, `-nojava` and `phases-rerun` in).
- `publish-phases.test.sh`: `phase_checks` (all but the re-run scenarios) and `phase_rerun_checks`, `ph_cleanup` (the removal of the scratch directory, was inline).
- `test.yml`: gate jobs 5 → 8 (`publish-gate-phases-rerun`, `publish-gate-readonly-gate-good|bad|nojava` for `publish-gate-readonly-gate`; `pins` in `publish-gate-rest`), jobs listed longest first (`ring`, `suites`, the gate jobs, the embedded jobs, `scaffold`) and the suites matrix with the Swift parts and Go first; 23 jobs per push.
- `publish-jobs.test.sh`: container groups = `gate phases phases-rerun readonly readonly-gate-good readonly-gate-bad readonly-gate-nojava readonly-full pins`; layout mutants 66 → 77.
- `publish-timing.selftest.sh`: the 19 groups and their functions, `ro_split` for the new scenario functions, `ph_split` (new): each phase check function runs in exactly one phase group; 4 mutants.
- `publish-workflow.test.sh`: the required timeout of the gate and embedded jobs is derived from the job names (`publish-gate-*`, `embedded-*`) instead of a hand-written list that named the old jobs.
- Swift (worker): see the Swift section.

## Swift: the strict release build merged into the speed build (worker, verified by the parent)

- `run-suite.sh`: the library-only `release` step is gone; `swift_strict=(-Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete)` is on the one release build, `swift build -c release --build-tests`, inside `swift_speed`. Plans: `all` = resolve debug test list fuzz tsan sanitized speed deps (9 steps, one release build), `tests` unchanged, `gates` = resolve tsan list sanitized deps (5), `speed` = resolve speed (the strict build, the list of the release build and the speed run inside). SW-9 now covers the test targets as well.
- `run-suite-swift.test.sh`: command lists, stop lists and notice rows for the new plans; new rule S2f: the single run and the speed part build release exactly once, with `--build-tests` and both flags, and the tests and gates parts build no release and set no strict flag. The old S5 "no tests built after the release build failed" is reworded to "a release build failure stops the speed run and the dependency check" (the ordering it covered, library build before debug build, is gone). 19 mutants of `run-suite.sh` (flags dropped one by one, flags moved into `swift_opts` or onto the sanitizer build, `--build-tests` dropped, a second release build, a release build in `gates`/`tests`, the failure ignored with `|| true`) plus the old design were all rejected.
- Real runs in `swift:6.3.3` (Linux arm64 container on the Mac, fresh build output, the exact CI command `docker compose -f docker-compose.test.yml run --rm -e PACKBIN_SWIFT_PART=<part> swift`): `speed` PASS, resolve 3 s, `swift_speed` 99 s (release build 92.7 s), total 102 s, no diagnostic in the test targets; `gates` PASS, tsan build 29 s, sanitized run 92 s, total 126 s. A planted warning (`let neverUsed = 1` in a new test file in a scratch copy) failed the speed part with exit 1 and the compiler's own message: SW-9 catches a warning in the test code.
- Side effect on the Mac single run (`all`): the strict build now runs after the sanitizer (was step 2), so an SW-9 failure shows up later there. Not changed.

## First CI run (run 39024316436, `c0e8019`, `dev` push, 23 jobs, all green)

Wall 275 s (created 10:17:11, last job done 275 s later); the loop 31 runs were 375, 344 and 369 s. Per job: duration, with the wait for a runner slot in brackets (from `created_at`, `started_at`, `completed_at` of the jobs API; 23 jobs against the free plan's 20 concurrent):

| Job | s | Notice |
|-----|--:|--------|
| `ring` | 273 | unchanged job: the wall |
| `suites (swift, tests)` | 246 | resolve 4, debug build 100, tests 36, list 2, fuzz 71 |
| `publish-gate-readonly-gate-good` | 184 (wait 63) | readonly-gate-good 121 |
| `suites (swift, speed)` | 224 | resolve 4, `swift_speed` 188 (release build with the strict flags and the tests, list, speed run) |
| `embedded-esp-core` | 213 | esp32s3 35, esp32c3 31, Arduino-ESP32 example 85 |
| `publish-gate-readonly-gate-nojava` | 179 (wait 30) | readonly-gate-nojava 94 |
| `publish-gate-readonly` | 205 | gate 88, readonly 26 |
| `publish-gate-rest` | 205 | readonly-full 35, workflow 39, pins 26, vcpkg 15, go 12, npm 8, the rest 0 to 1; group total 138 |
| `publish-gate-phases` | 196 | phases 105 |
| `suites (swift, gates)` | 191 | resolve 5, tsan build 100, list 3, sanitized run 48, deps 1; steps 157 |
| `publish-gate-readonly-gate-bad` | 176 | readonly-gate-bad 88 |
| `publish-gate-swift` | 171 | swift 166 |
| `publish-gate-phases-rerun` | 170 | phases-rerun 108 |
| `embedded-esp-packages` | 162 | ESP-IDF example 65, Pico example 40 |
| other | 26 to 132 | go 132, rust 69 (wait 35), python 92, csharp 79, scaffold 71, embedded-arm 60, cpp 58, typescript 31, java 26 |

The jobs that waited for a slot were `readonly-gate-good` (63 s), `suites (rust)` (35 s) and `readonly-gate-nojava` (30 s): not the last three in the file, so the queue does not start jobs in file order. None set the wall (the slowest, `readonly-gate-good`, ended at 247 s).

## Second CI run (run 39025925515, `73ba412`, the close push of `dev`, 23 jobs, all green)

Wall 264 s (created 10:42:29). **AC-1: the median of the two runs of the final code is 269.5 s (275 and 264 s), at most 330 s: met by 60 s; the goal of about 5 minutes (300 s) is met by both runs.** Loop 31: 344 and 369 s (median 356.5 s).

| Job | s | Notice |
|-----|--:|--------|
| `ring` | 261 | unchanged job: the wall again |
| `suites (swift, speed)` | 218 | `swift_speed` 182 |
| `publish-gate-rest` | 209 | pins 22 |
| `suites (swift, gates)` | 148 (wait 60) | tsan build 69, sanitized run 31; steps 106 |
| `embedded-esp-core` | 200 | |
| `readonly-gate-bad` / `-nojava` / `-good` | 186 / 180 / 177 | 122 / 118 / 86 |
| `publish-gate-phases-rerun` / `phases` | 185 / 175 | 120 / 113 |
| `publish-gate-readonly` | 183 | |
| `suites (swift, tests)` | 180 | debug build 45, tests 19, fuzz 66; steps 135 |
| other | 28 to 147 | go 134, python 106, `publish-gate-swift` 114, csharp 74, scaffold 65, cpp 63, rust 57, embedded-arm 56, typescript 37 (wait 61), java 28 (wait 67) |

Three jobs waited for a slot again (`suites (swift, gates)` 60 s, `typescript` 61 s, `java` 67 s) and none set the wall: which jobs wait changes from run to run. The runner was faster in run 2 (every Swift step about 30 % shorter than in run 1), so the two walls differ by 11 s while individual jobs differ by up to 66 s.

## Step 11 (`scripts/loop-tests.sh`, commit eb1da7d)

10 passed, 3 skipped as unchanged, 0 failed, 902 s; no stage needed the serial retry (load 20 to 69). The gate stage: eight shares at once, wall 391 s against a sum of 2 395 s (ratio 0.16), tree unchanged (1 712 paths); NOT RUN inside the gate on this Mac: the two vcpkg checks (no vcpkg tool), as in every Mac run. Details in `_docs/03_implementation/test_run_loop32_report.md`.

## Review disposition (one total review, high, 7 findings)

Fixed: the over-long comment line (`publish-gate.test.sh`), the stale deploy docs. Skipped with reason: pull lists of eight images in seven jobs (efficiency, Medium: the guard demands the full list and the cut belongs with C3; next round), job order unguarded (the first run showed file order does not decide who waits), the duplicated strict build line in `swift_speed` (same shape as before the loop), the bad-fixture check accepting any non-zero exit (the `pack csharp` hex assertion behind it needs a log from a real run), SW-9 reported by the speed part (recorded; the strict flags are in `swift_strict`, one place).
