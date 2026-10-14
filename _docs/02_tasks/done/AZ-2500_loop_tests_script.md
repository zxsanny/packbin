---
loop: 25
branch: dev
---

# Loop test run: stages chosen by changed paths, an incremental smoke, language suites in parallel

**Task**: AZ-2500_loop_tests_script
**Name**: Loop test run: stages chosen by changed paths, an incremental smoke, language suites in parallel
**Description**: One script runs the loop's test stages. A stage runs only when a file it covers changed since the commit where it last passed; the suites run in parallel; the publish gate is skipped when the publish path did not change.
**Complexity**: 3 points
**Dependencies**: none
**Component**: scripts
**Tracker**: AZ-2500
**Epic**:

## Problem

Step 11 and the smoke each ran every stage (about 43 minutes in loop 25, 24 of them the publish gate twice) although the loop changed no publish file and the smoke repeated step 11 almost unchanged. The suites ran one after the other.

## Outcome

- `scripts/loop-tests.sh` with `--plan`, `--all`, `--only`, `--jobs`, `--serial`; stamps in `test-results/stamps`.
- `scripts/loop-tests.test.sh`, a step of the `scaffold` job in `test.yml`.
- The policy in `_docs/04_deploy/deployment_procedures.md` § Loop test script, including the smoke rule for a stage skipped as unchanged.

## Scope

### Included

- Owns (exclusive write): `scripts/loop-tests.sh`, `scripts/loop-tests.test.sh`, one step in `.github/workflows/test.yml`, the deployment procedures section.

### Excluded

- Any change to a suite, to the ring or to the gate themselves; the choice to cache the gate's package downloads (open row P1 of the loop 26 handoff).

## Acceptance Criteria

**AC-1: Selection**
Given a stamp for each stage and a change
When `--plan` runs
Then exactly the stages that cover the changed file run (a C# source selects the C# suite, the ring and AC-10; README.md selects the publish gate only; a file added in a package selects the gate; a test file does not select the ring or the gate), and a missing, foreign or dirty state runs the stage.

**AC-2: Parallel with a serial retry**
Given a suite that fails once beside the others
When the script runs
Then it is re-run alone, both results show, and it passes; a suite that fails again fails the run (exit 1).

**AC-3: Stamps**
Given a stage that passes
When the tree is clean
Then its stamp is the commit; when the tree is dirty, or the stage fails, no stamp is written.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | `scripts/loop-tests.test.sh` cases 1 to 13 | selection as above; mutation-checked (a publish-gate pattern widened fails it) |
| AC-2, AC-3 | `scripts/loop-tests.test.sh` case 14 with a fake `docker` | retry, exit code, stamps; mutation-checked (stamp from a dirty tree fails it) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-2 | `--all --only typescript,rust,java,cpp --jobs 4` on this repo | wall time | 28 s against 70 s in sequence | |
