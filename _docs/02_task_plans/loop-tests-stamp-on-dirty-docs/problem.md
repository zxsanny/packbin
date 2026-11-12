---
loop: 117
branch: dev
tracker: AZ-4243
---
# `scripts/loop-tests.sh`: a dirty `_docs/` must not block a stage stamp

Seeded from `queue_item.md` beside this file (source: loop 112 record leftovers).

## Problem
`stamp_pass` (`scripts/loop-tests.sh`) writes a passing stage's stamp only when `git status --porcelain` is empty apart from `_docs/_autodev_state.md` (AZ-3369). Step 11 runs with the loop's documents uncommitted, so it writes no stamp and later plans rerun stages that passed (9 of 15 in loop 112). Loops 112 and 116 seeded the stamps by hand with the last total run.

## Outcome
A passing stage writes its stamp when every dirty or untracked path is under `_docs/`; any other dirty path still blocks it. Nothing changes in what a stage covers (`covers` names no `_docs/` path).

## Code sections
`scripts/loop-tests.sh` (`stamp_pass`), `scripts/loop-tests.test.sh` (execution section, plan section), `_docs/04_deploy/deployment_procedures.md` § Loop test script.

## Acceptance checks
Task spec `_docs/02_tasks/todo/AZ-4243_loop_tests_stamp_on_dirty_docs.md`.

## Needs
none

## Constraints
No stage covers `_docs/**`; that stays so (a plan test pins it). `scaffold` covering `scripts/probes/` is not changed here.
