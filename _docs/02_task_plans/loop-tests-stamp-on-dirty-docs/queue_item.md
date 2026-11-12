---
kind: queue-item
order: 500
source: loop112 record (leftovers: process); `_docs/03_implementation/batch_01_loop112_report.md` discovery 7
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# `scripts/loop-tests.sh`: a dirty `_docs/` must not block a stage stamp

## Problem
The script writes a stage's stamp only when the tree is clean apart from the state file. Step 11 always runs with the loop's documents uncommitted, so no stamp is written and the next default plan runs stages again that had passed (9 of 15 in loop 112). The loops work around it by seeding `LOOP_TESTS_STAMPS` with the last total run.

## Outcome
A total run with only `_docs/**` changes in the tree writes its stamps, and the next plan skips the stages nothing touched, without a seeded stamp directory.

## Code sections
`scripts/loop-tests.sh` (the stamp write and its clean-tree test), `scripts/loop-tests.test.sh`, `_docs/04_deploy/deployment_procedures.md` § Loop test script.

## Acceptance checks
- With only files under `_docs/` modified or untracked, a passing stage writes its stamp; with any other dirty path it does not (as today).
- `scripts/loop-tests.test.sh` covers both and passes.
- `--plan` after such a run lists the passed stages as skipped with the stamp's commit.
- The procedure text says the same.

## Needs
none

## Constraints
No stage covers `_docs/**` today; that stays so. Measured beside it and not decided here: `scaffold` takes 362 to 386 s for a change under `scripts/probes/` that no scaffold test reads (narrowing what `scaffold` covers is its own question).
