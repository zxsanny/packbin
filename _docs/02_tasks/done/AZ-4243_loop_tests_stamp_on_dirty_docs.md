---
loop: 117
branch: dev
---

# loop-tests.sh: a dirty `_docs/` must not block a stage stamp

**Task**: AZ-4243_loop_tests_stamp_on_dirty_docs
**Name**: loop-tests.sh: a dirty `_docs/` must not block a stage stamp
**Description**: A passing stage writes its stamp when the only dirty or untracked paths are under `_docs/`.
**Complexity**: 2 points
**Dependencies**: AZ-3369 (done: the state file alone does not block a stamp)
**Component**: `scripts/loop-tests.sh`, `scripts/loop-tests.test.sh`, `_docs/04_deploy/deployment_procedures.md`
**Tracker**: AZ-4243
**Epic**: AZ-4133

Queue item `loop-tests-stamp-on-dirty-docs` (loop 112 leftovers). Problem: `_docs/02_task_plans/loop-tests-stamp-on-dirty-docs/problem.md`.

## Acceptance Criteria

**AC-1: `_docs/` alone does not block a stamp**
Given a tree whose only modified or untracked files are under `_docs/` (a tracked file edited, a new file added)
When a stage passes
Then its stamp is written with `HEAD`.

**AC-2: any other dirty path still blocks it**
Given a tree with a modified file outside `_docs/` (as today: `README.md`), or an untracked one outside `_docs/`
When a stage passes
Then no stamp is written.

**AC-3: the next plan skips it**
Given the AC-1 run, and then the `_docs/` changes committed
When `--plan` runs
Then the passed stage is `SKIP (unchanged since <HEAD of the run>)`.

**AC-4: no stage covers `_docs/`**
Given a commit that changes only a `_docs/` file
When `--plan` runs with every stage stamped before it
Then every stage is skipped.

**AC-5: documented**
`_docs/04_deploy/deployment_procedures.md` § Loop test script says a stamp is written when the tree is clean apart from `_docs/`.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `loop-tests.test.sh` execution: edited tracked `_docs/` file and a new untracked one, `--all --only rust` with the fake docker | `stamps/rust` = HEAD |
| AC-2 | dirty `README.md` (existing test); untracked `go/new.go` | no stamp |
| AC-3 | after AC-1, commit the `_docs/` change, `--plan --only rust` | `PLAN rust SKIP (unchanged since <sha>)` |
| AC-4 | plan section: `change _docs/notes.md` | every stage skips |

## Constraints
- The selection (`covers`, `decide`) does not change.
- `scripts/loop-tests.test.sh` stays hermetic and passes under `bash` and `shellcheck`.
