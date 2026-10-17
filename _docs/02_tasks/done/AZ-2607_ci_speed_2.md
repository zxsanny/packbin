---
loop: 31
branch: dev
---

# CI speed 2: readonly gate split, Swift parts balanced, parallel Mac gate

**Task**: AZ-2607_ci_speed_2
**Name**: CI speed 2
**Description**: `test.yml` wall time falls from 382 to 418 s to at most 360 s; the Mac publish gate stage runs its shares in parallel.
**Complexity**: 5 points at intake; the owner added C4 and the Swift third part on 2026-10-17 after the first CI run (about 8 points of work in all)
**Dependencies**: AZ-2600
**Component**: ci
**Tracker**: AZ-2607
**Epic**: AZ-2223

## Outcome

- The `readonly` gate group is three groups; the gate jobs carry shares chosen from measured group seconds.
- Every suite writes one timing notice with its step seconds; the Swift parts are balanced from those numbers.
- `scripts/loop-tests.sh` runs the CI gate shares in parallel on the Mac.
- `publish-phases.test.sh` is under 500 lines; review28 #4 audited.
- (Owner decision 2026-10-17, C4) the `embedded` job is three jobs from one target table; the Swift suite is three parts; the gate jobs are regrouped by the measured seconds.

## Acceptance Criteria

**AC-1: CI wall**
Given the final code of the loop
When `test.yml` runs on two `dev` pushes
Then the median wall time (run created to last job done) is at most 360 s (baseline 418 and 382 s, median 400 s), and every job is green.

**AC-2: timing without a token**
Given a `test.yml` run
When the check-run annotations of a gate job or a suite job are read without a token
Then exactly one notice per job lists the seconds of every group (gate) or every step (suite) that job ran.

**AC-3: no check lost**
Given `gate_groups` and the gate jobs of `test.yml`
When `publish-jobs.test.sh` runs
Then every group runs in exactly one job, an unknown, missing or repeated group fails with its name, and every check function of the old `readonly` group (7) runs in exactly one new group; every Swift step runs in exactly one part (`run-suite-swift.test.sh`); each rule has a mutant that the guard rejects.

**AC-4: parallel Mac gate**
Given `scripts/loop-tests.sh` selects the `publish-gate` stage
When it runs
Then the shares are the `--groups` lists of the gate jobs in `test.yml` (no second list), they run at the same time, the stage wall time is at most 0.7 times the sum of the shares' own seconds in the same run, a failing share fails the stage and is named, and the tree manifest is the same before and after the stage.

**AC-5: file length**
Given `publish-phases.test.sh`
When the loop ends
Then it and every file split from it is at most 500 lines, and `phase_checks` runs the same 9 check functions as before.

**AC-6: host delete audit**
Given `scripts/`, `.github/workflows/` and `cpp/embedded/`
When the audit runs
Then every site that deletes a host path right before a container binds it is listed in `_docs/loops/loop31/notes31.md` as fixed or harmless with a reason, and none is left unfixed and harmful.

**AC-7: embedded split (C4)**
Given `cpp/embedded/run.sh` and the `embedded-*` jobs of `test.yml`
When `run-parts.test.sh` and `publish-jobs.test.sh` run
Then each of the 9 embedded targets (4 arm, 5 ESP) is in exactly one part (arm, ESP `core`, ESP `packages`), each part is called by exactly one `embedded-*` job, the unsplit forms still work, each job writes one timing notice with its target seconds, and no job of `test.yml` is the old `embedded` job; the `embedded-*` jobs are each at most 240 s on CI.

## Constraints

- No tag, no registry upload, no `main` push; each `dev` push asked of the owner.
- One total review and one step 11 run (`scripts/loop-tests.sh`); workers run only their own guard tests.

See `_docs/02_task_plans/ci-speed-2/problem.md` and the plan `_docs/loops/loop31/plan31.md`.
