---
loop: 33
branch: dev
---

# CI speed 4: ring off the critical path, per-job image pulls

**Task**: AZ-2626_ci_speed_4
**Name**: CI speed 4
**Description**: `test.yml` wall time falls from a median of 269.5 s (275 and 264 s) to a median of at most 250 s by taking the `ring` job's pulls and driver builds off its critical path; each gate job pulls only the images its groups start; no check is removed.
**Complexity**: 5 points
**Dependencies**: AZ-2625
**Component**: ci
**Tracker**: AZ-2626
**Epic**: AZ-2223

## Problem

The `ring` job (255 to 268 s) sets the wall: every step waits for the one before it, although the gcc and swift image pulls (21 to 31 s and 42 to 52 s) and the Swift driver build need nothing the setup actions install, and the npm, cargo and Go driver builds do not depend on each other. Seven gate jobs pull all eight images (57 to 87 s) where three start five and one starts seven.

## Outcome

- `ring` takes at most 180 s: the Swift wiring check runs in `scaffold`; the pulls and the Swift driver build start in the background right after checkout; the other driver builds run at the same time; a wait step (bounded, naming a failed or hung build with its log) comes before the toolchain check; one timing notice gives the seconds.
- Each gate job pulls exactly its images; the guard refuses a missing and an extra image.

## Scope

### Included
- `test.yml` (`ring`, `scaffold`, the `publish-gate-*` pull lines and comments); a driver-preparation script and its test (stand-in commands: success, failure, hang); the Go and Swift rules of `ring-wiring.test.sh` and `ring-wiring-swift.test.sh`; the pull rule, group → images map and mutants of `publish-jobs.test.sh`; the scaffold list of `scripts/loop-tests.sh`; docs (`ci_cd_pipeline.md`, `ci_metrics_2026-10-16.md` section 9, `module-layout.md`).

### Excluded
- C3 caches, the PlatformIO install, a runner image pin, `language-pair.sh` changes, AZ-2068, tags, F44, the `main` push.
- Catching a group that starts a new image without a map update (scenario 8: only slower, accepted-risk).

## Acceptance Criteria

AC-1 to AC-10 are in `_docs/02_task_plans/ci-speed-4/problem.md` (owner batch answer 2026-10-17). In short:

**AC-1: CI wall.** Two `dev` pushes of the final code: median wall at most 250 s, all jobs green.
**AC-2: ring job.** At most 180 s on both runs; the ring runs every kind and member as before.
**AC-3: background preparation.** Pulls and Swift driver build start right after checkout; npm, cargo, Go builds at once; all eight toolchains checked before the ring.
**AC-4: failure and hang.** A failed background build fails the wait step, named, log printed; a hang gives up within 15 minutes, named.
**AC-5: timing notice.** One notice with the seconds of each pull, build and the wait.
**AC-6: Swift wiring in scaffold.** Exactly once, in `scaffold`, no `if`, no `continue-on-error`.
**AC-7: pull lists.** Exact per-job image lists (5, 7, 8, 0); missing and extra refused by name; four new mutants; the three five-image pull steps shorter than in run 39025925515.
**AC-8: no check lost.** Every group in one job, after its pull; the named guards pass; a mutant per changed rule.
**AC-9: Mac step 11.** `scripts/loop-tests.sh` passes once.
**AC-10: file length.** Changed files at most 500 lines.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3, AC-4, AC-5 | the preparation script's test with stand-in `docker`, `npm`, `cargo`, `ring-go.sh`, `ring-swift.sh`: success, a failing build, a failing pull, a hang under a short limit | success prints the timing notice; each failure exits non-zero naming the build with its log; the hang gives up at the limit |
| AC-6, AC-8 | `ring-wiring.test.sh`, `ring-wiring-swift.test.sh` with mutants (Swift wiring back in `ring`, dropped from `scaffold`; Go or Swift build no longer reached; wait after the toolchain check) | each mutant rejected, named |
| AC-7, AC-8 | `publish-jobs.test.sh` mutants: phases pull without java, nojava pull without python, phases pull with swift, rest pull with go | each rejected, naming job and image |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2, AC-5, AC-7 | the final code pushed to `dev` twice | `test.yml` run times from the jobs API and the job pages | wall median ≤ 250 s, `ring` ≤ 180 s, five-image pulls shorter, notice present | — |
| AC-9 | the final tree on the Mac | `scripts/loop-tests.sh` | all stages pass | — |

## Constraints

- Owner decisions D1 to D6 (`problem.md`). No tag, no registry upload, no `main` push; each `dev` push is asked of the owner.
- One total review and one step 11 run; no per-batch review or test run.

## Flagged concerns

See `_docs/02_task_plans/ci-speed-4/problem.md` § Flagged concerns (no Critical; Ubuntu 26 move, background processes, four builds on four cores, CI variance open).
