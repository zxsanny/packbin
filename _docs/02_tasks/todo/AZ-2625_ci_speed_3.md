---
loop: 32
branch: dev
---

# CI speed 3: readonly-gate in three jobs, phases in two, pins moved, Swift strict build merged

**Task**: AZ-2625_ci_speed_3
**Name**: CI speed 3
**Description**: `test.yml` wall time falls from a median of 356.5 s (344 and 369 s) to a median of at most 330 s, the goal being about 5 minutes; no check is removed.
**Complexity**: 5 points at intake (loop 31 planned 5 and did about 8: the second round is in the estimate)
**Dependencies**: AZ-2607
**Component**: ci
**Tracker**: AZ-2625
**Epic**: AZ-2223

## Outcome

- The three real gate scenarios of `ro_gate_checks` (good, bad, nojava) are three groups in three jobs (`readonly-gate-good`, `readonly-gate-bad`, `readonly-gate-nojava`); `pins` runs in `publish-gate-rest`.
- `phase_checks` is two groups in two jobs, cut by the Mac-measured seconds of each scenario: `phases` (static checks, fabricated artifacts, empty plan, build-only, full publish, failure injection, pipeline violations) and `phases-rerun` (the re-run and registry-policy scenarios); each pays `ph_setup`.
- The Swift `gates` part loses the strict release build: the speed part's release build (with tests) carries the strict flags, so the check stays and the build is made once.
- `test.yml` lists the long jobs first; the first CI run's start times show whether the 23 jobs queue.

## Acceptance Criteria

The criteria AC-1 to AC-9 are in `_docs/02_task_plans/ci-speed-3/problem.md` (owner answer 2026-10-17: AC-1 is a median of at most 330 s). In short:

**AC-1: CI wall.** Two `dev` pushes of the final code: median wall at most 330 s, all jobs green.
**AC-2: readonly-gate in three jobs.** Three groups, one scenario and one job each; each job at most 220 s on CI.
**AC-3: pins moved.** `pins` in `publish-gate-rest`.
**AC-4: phases in two groups.** Two groups in two jobs; the 8 phase check functions each in exactly one; each job at most 220 s on CI.
**AC-5: Swift gates part.** Strict release build (SW-9) still runs in exactly one part; `gates` at most 200 s and no part above 250 s on CI.
**AC-6: no check lost.** 19 gate groups, each in exactly one job; every container group after the pull; a mutant per changed rule rejected.
**AC-7: queue and job count.** 23 jobs; the start times of the first run are read and written to the notes.
**AC-8: Mac gate.** `scripts/loop-tests.sh` runs the new shares read from `test.yml`; tree unchanged; ratio reported.
**AC-9: file length.** Changed source files at most 500 lines.

## Constraints

- No tag, no registry upload, no `main` push; every `dev` push is asked of the owner.
- One total review and one step 11 run (`scripts/loop-tests.sh`); workers run only their own guard tests.
- Not in scope: C3, `ring`, the PlatformIO install, AZ-2068, F44.

See `_docs/02_task_plans/ci-speed-3/problem.md` and the plan `_docs/loops/loop32/plan32.md`.
