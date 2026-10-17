---
loop: 33
branch: dev
---

# Loop 33 — CI speed 4 (AZ-2626, epic AZ-2223)

Owner (2026-10-17): picked "CI speed 4" from `_docs/loops/loop32/handoff33.md`, then answered the batched question (D1 to D6) "accept all recommended": D1 median of two `dev` runs at most 250 s and `ring` at most 180 s on both; D2 one `ring` job, the Swift wiring check moved to `scaffold`, the gcc and swift pulls and the Swift driver build started in the background right after checkout, the npm, cargo and Go driver builds at the same time, a timing notice per build; D3 each gate job pulls exactly the images its groups start (5, 7 or 8), the guard refuses a missing and an extra image; D4 `ubuntu-latest` kept, the Ubuntu 26 move (from 2026-10-19) is a concern, a break is fixed in the second push; D5 one more code push allowed if the first run misses; D6 C3 caches out.

## What

`test.yml` wall was 275 s and 264 s on the loop 32 code (runs 39024316436 and 39025925515, median 269.5 s, 23 jobs). The wall is `ring`. Its steps (seconds, run 1 / run 2, from the job pages):

| Step | Run 1 | Run 2 |
|------|------:|------:|
| set up, checkout | 3 | 5 |
| Swift ring wiring (a ruby/bash check, no toolchain) | 25 | 18 |
| setup-dotnet, node, python, java, go, rustup | 29 | 32 |
| GCC image (`docker pull gcc:16`) | 21 | 31 |
| toolchain versions (`swift --version` in `swift:6.3.3`: the 4 GB pull) | 42 | 52 |
| driver dependencies and builds (npm ci, cargo, Go, Swift release build in `swift:6.3.3`) | 101 | 76 |
| cross-language ring | 47 | 41 |
| job | 268 | 255 |

Every step runs after the one before it, although the pulls and the Swift driver build need nothing the setup actions install. The gate jobs spend 57 to 87 s on `pull images` (all eight images); `phases`, `phases-rerun` and `rest` start only csharp, typescript, python, rust and java, `readonly-gate-nojava` everything but java (code trace, loop 33 intake).

1. **`ring`**: the Swift wiring check moves to `scaffold`; the gcc and swift pulls and the Swift driver build run in the background from the first step after checkout; the npm, cargo and Go driver builds run at the same time; a timing notice gives the seconds of each.
2. **Pull lists**: each `publish-gate-*` job pulls exactly the images its groups start; `publish-jobs.test.sh` holds the group → images map and refuses a missing and an extra image.

Goal: `ring` about 150 to 170 s; the wall then is the Swift suite parts (176 to 246 s). No check removed; every group, Swift step and embedded target in exactly one job.

Not in scope: C3 (caches), the PlatformIO install in the Arduino-ESP32 target, AZ-2068, any tag or registry upload, F44, the `main` push, a runner image pin.

## Code sections / UI locations for this loop

Backend only (CI and test scripts), named in the option the owner picked and the decisions:

- `.github/workflows/test.yml` (`ring` job, `scaffold` job, `publish-gate-*` pull steps and their comments)
- `.github/workflows/ring-*.sh` and a new driver-preparation script with its test (the background pulls and builds); `language-pair.sh` unchanged
- Guards: `ring-wiring.test.sh` (the Go build rule), `ring-wiring-swift.test.sh` (the Swift wiring step and driver build rules), `publish-jobs.test.sh` (the pull rule and mutants), `scripts/loop-tests.test.sh` if a scaffold step it reads changes
- Docs: `_docs/04_deploy/ci_cd_pipeline.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` (section 9), `_docs/02_document/module-layout.md`

## Acceptance criteria

(Targets from the owner's batch answer, 2026-10-17.)

**AC-1: CI wall.** Given the final code, when `test.yml` runs on two `dev` pushes, the median wall time (run created to last job done) is at most 250 s (loop 32: 275 and 264 s, median 269.5 s) and every job is green.

**AC-2: ring job.** On both runs of AC-1 the `ring` job takes at most 180 s (loop 32: 268 and 255 s), and the ring still runs every kind of `language-pair.sh` with every member (`language-pair.sh` unchanged; the job prints the same hand-off line count as run 39025925515).

**AC-3: background preparation.** The gcc and swift image pulls and the Swift driver build start in the step right after checkout and run while the setup actions run; the npm, cargo and Go driver builds run at the same time as each other; `ring-toolchains.sh` still checks all eight toolchains before the ring, through `ring-cxx.sh`.

**AC-4: failure and hang.** When any background pull or driver build fails, the job fails in the step that waits for it, naming that build and printing its log; when one hangs, the wait gives up after at most 15 minutes (below the job's 30-minute timeout), naming it. Proven by the new script's test with stand-in commands (fail, hang with a short limit, success) run in `scaffold`.

**AC-5: timing notice.** The `ring` job writes one notice (readable without a token, as the gate and suite notices) with the seconds of each pull, each driver build and the wait.

**AC-6: Swift wiring in scaffold.** `ring-wiring-swift.test.sh` runs in `scaffold` (exactly once in `test.yml`, no `if`, no `continue-on-error`) and no longer in `ring`; its own rules and mutants follow the move.

**AC-7: pull lists.** Each `publish-gate-*` job pulls exactly the union of the images its groups start: `phases`, `phases-rerun`, `rest` the five csharp, typescript, python, rust, java; `readonly-gate-nojava` all but java; `readonly`, `readonly-gate-good`, `readonly-gate-bad` all eight; `swift` none. `publish-jobs.test.sh` refuses a missing image and an extra image, naming the job and the image; at least the mutants "phases pull without java", "nojava pull without python", "phases pull with swift" and "rest pull with go" are rejected, and the existing pull mutants still are. On both AC-1 runs the `pull images` step of `phases`, `phases-rerun` and `rest` is shorter than in run 39025925515 (57, about 57 and 59 s).

**AC-8: no check lost.** Every gate group in exactly one job, every container group after its pull; the guards `publish-jobs.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `publish-workflow.test.sh`, `publish-timing.selftest.sh`, `scripts/loop-tests.test.sh` and the new script's test pass; one mutant per changed rule is rejected.

**AC-9: Mac step 11.** `scripts/loop-tests.sh` passes (one total run), the tree unchanged by the gate stage.

**AC-10: file length.** Every changed source file is at most 500 lines (`ring-wiring.test.sh` is at 500 today: a rule that changes there takes no net lines).

## Expected results

| Input | Expected |
|-------|----------|
| `test.yml` run of the final code on a `dev` push, twice | wall median at most 250 s; `ring` at most 180 s each; all jobs green |
| the new preparation script's test, a stand-in Swift build that exits 1 | the wait step exits non-zero, names the Swift driver build, prints its log |
| the same, a stand-in pull that sleeps past a 2 s limit | the wait gives up after about 2 s and names the pull |
| `publish-jobs.test.sh` on a `test.yml` whose `phases` pull drops java / adds swift | fails, naming `publish-gate-phases` and the image |
| `ring-wiring-swift.test.sh` on a `test.yml` with the Swift wiring step back in `ring` / dropped from `scaffold` | fails, naming the step |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The gain is small: the 5-minute goal is met and the Swift suite parts (176 to 246 s) are the next floor | owner picked the round knowing the estimate | accepted-risk | Low |
| `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19 (GCC, Swift and setup actions may change under the measurement runs) | D4: keep `ubuntu-latest`; a break is fixed in the second push; record which image each run used | open | Medium |
| Background processes must outlive their step and not hold the step's output open; the wait must not hang | output to files, stdin from `/dev/null`, a bounded wait, the test with stand-ins; first CI run proves it on the runner | open | Medium |
| Four builds at once on a 4-core runner (cargo, Go, npm, the Swift release build in a container) may slow each other | the timing notice shows the seconds; tune the order in the second push if needed | open | Medium |
| The group → images map in `publish-jobs.test.sh` is written by hand: a group that later starts a new image is not caught, only slower (compose pulls a missing image on first use; no `--pull never` anywhere) | document the map next to the groups; the cost of drift is time, not a failure | accepted-risk | Low |
| The same code varies about 1.4x between CI runs | median of two runs; never one run as proof | open | Medium |
