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
