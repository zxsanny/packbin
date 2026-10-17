# Batch 1 report — loop 33

Task: AZ-2626 (CI speed 4, 5 points), one batch. No per-batch review (owner preference: one total review before step 11). No worker: the parent did all of it (every part touches `test.yml`).

| Part | Status | Evidence |
|------|--------|----------|
| Ring preparation script (AC-3, AC-4, AC-5) | Done | `ring-prepare.sh start <dir> <image>...` (the pulls at the same time, the Swift build after the swift pull, all in the background), `build <dir>` (npm, cargo, Go at the same time), `wait <dir>` (bounded at 900 s, names a failed, skipped or unfinished build with the end of its log, one `ring preparation timing` notice on GitHub Actions); `ring-prepare.test.sh` with stand-ins: success, four failures, a hang under a 2 s limit, usage and state dir rules, 4 mutants of the script caught; one real run on the Mac (below) |
| `ring` job (AC-2, AC-3) | Done | after checkout `ring-prepare.sh start "$RUNNER_TEMP/ring-prepare" "gcc:$RING_GCC" "swift:$RING_SWIFT"`; the setup actions; `build` + `wait`; `toolchain versions`; the ring. Steps gone from the job: `Swift ring wiring` (to `scaffold`), `GCC image` (into the start step) |
| Swift wiring in `scaffold` (AC-6) | Done | `scaffold` runs `ring-wiring-swift.test.sh` and `ring-prepare.test.sh`; `ring-wiring-swift.test.sh` holds the check in `scaffold` and out of `ring`, the start and wait on the same state dir before the ring, the swift image in the start line; mutants w3, w7 to w11 rejected |
| Go rule (AC-8, AC-10) | Done | `ring-wiring.test.sh` accepts the Go build through `ring-prepare.sh build` (which calls `ring-go.sh`: `ring-prepare.test.sh`); the mutant deletes that line now; the file stays at 500 lines |
| Pull lists (AC-7) | Done | `phases`, `phases-rerun`, `rest`: csharp typescript python rust java; `readonly-gate-nojava`: all but java; `readonly`, `readonly-gate-good`, `readonly-gate-bad`: all eight; `swift`: none. `publish-jobs.test.sh`: a group → images map, the exact union per job, a named error for a missing and for an extra image, a pull in a job whose groups start no container refused; 8 new mutants (85 in all), each refused with the right message (checked one by one) |
| Mac step 11 list (AC-9) | Done | `scripts/loop-tests.sh` scaffold stage runs `ring-prepare.test.sh` |

CI-parity (focused, the scaffold scripts and guards this batch touches): `ring-prepare.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `publish-jobs.test.sh`, `publish-timing.selftest.sh`, `scripts/loop-tests.test.sh`, `publish-gate.test.sh --groups workflow,static`: all PASS. `shellcheck` clean on the two new files.

## Real run on the Mac (14:28 to 14:35, load 7 to 11)

`ring-prepare.sh start <dir> gcc:16 swift:6.3.3`, `build`, `wait` with the real commands (Docker Desktop, npm, cargo, Go in `golang:1.27`, the local Swift): start returned at once, build 1 s (npm 1, cargo 0, Go 0: outputs current), `pull-gcc` 156 s, `pull-swift` 422 s, `swift-drivers` 0 s (stamp current), wait 422 s, all exit 0, timing lines as designed. The pulls of images already present took minutes on this Mac (Docker Desktop resolves the registry to IPv6 first; a container start was 0.4 s, Docker Hub answered the host in 1 s); on the runners the same pulls took 21 to 52 s, so this is a Mac network matter, recorded, not changed.

## Total review (built-in `/code-review`, high, 7 findings)

Fixed in the review commit: a failed `build` stopped the step before `wait` (background failures unreported, no notice): `build` now names its failures and `wait` is the verdict for every build, and `ring-wiring-swift.test.sh` holds build before wait, the wait last in its step, one state dir (mutant w12); image names with a registry path or twice the same name are refused by `start` before it makes the state dir; the wait polls every 0.2 s (was 1 s); the rule checks of the test assert the message, not only the exit status; a pull line naming an image twice is refused (mutant); the hang check's upper bound is 20 s (was 6 s). Skipped: the timing helpers of the test (they feed the failure messages and the hang bound). Found by a repeat of the test after the fixes (1 failure in 5 runs): the wait gave up up to 1 s before its limit (whole seconds, `-lt`); it now waits the full limit (`-le`) and the hang check demands at least 2 s; 3 more runs clean.

## Discovered during implementation

| Scenario or question | Spec ref | Proposed handling | clear / unclear |
|----------------------|----------|-------------------|-----------------|
| `ring-wiring.test.sh` demands that every `RING_*` variable appears in a step of the ring job; `RING_GCC` was only in the removed `docker pull "gcc:$RING_GCC"` step | AC-8 | the start step names the images it pulls (`"gcc:$RING_GCC" "swift:$RING_SWIFT"`), as the gate pull lines do, instead of the script reading them from the environment; the rule stays as it is | clear |
| If the start line did not pull the swift image, the Swift build would pull it lazily inside the build and the timing would hide it | AC-3, AC-5 | `ring-wiring-swift.test.sh` requires `"swift:$RING_SWIFT"` in the start line (mutant w11) | clear |
| `language-pair.sh` calls `ring-swift.sh` before each Swift driver command: a ring started before the background build ends would start a second build | AC-3 | the wait is held before the ring on the same state dir by `ring-wiring-swift.test.sh` (mutants w7, w8, w9) | clear |
| Time-based checks in the test (a start under 1.5 s, three builds under 5 s) would flake on a loaded Mac | AC-4 | the test reads the order of the stand-ins' begin and end lines instead of the clock | clear |
| The comment of `ro_reclaim` (`publish-readonly.test.sh`) says the typescript image is pulled by "the pull images step of the publish-gate job": every job that runs it still pulls typescript | AC-7 | unchanged | clear |
