---
loop: 25
branch: dev
---

# `run-suite.sh`: the six fail without their manifest (align with Go)

**Task**: AZ-2457_run_suite_missing_manifest_fail
**Name**: `run-suite.sh`: the six fail without their manifest (align with Go)
**Description**: D6 A: `run-suite.sh` for TypeScript, Python, Rust, C#, Java, C++ returns a non-zero exit and names the missing manifest when its manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, `*.csproj`, `pom.xml`, `cpp/CMakeLists.txt` or the project's equivalent) is missing — the Go wrapper's behavior. Today the six skip with a PASS row, which hides a corrupt tree.
**Complexity**: 2 points
**Dependencies**: none
**Component**: run-suite wrappers (`*/run-suite.sh`) in the six packages
**Tracker**: AZ-2457
**Epic**:

## Problem

AC-15 (`_docs/00_problem/acceptance_criteria.md`): "A language missing from the tagged tree publishes 0 packages." The release path trusts `run-suite.sh` to say the language is present. The Go wrapper (loop 24) fails loudly when `go/go.mod` is missing; the other six wrappers print `SKIP` and return 0, which turns a corrupt tree into a passing green signal and lets AC-15 be violated by accident. D6 A (handoff 25, D-batch 2026-10-14) aligns the six to Go.

Reference: `_docs/00_problem/acceptance_criteria.md` AC-15; `_docs/02_task_plans/pack-output-budget-and-parity/` or the publish-gate task plan where AC-15 wording lives; the Go wrapper of loop 24.

## Outcome

- Each of the six `run-suite.sh` wrappers returns a non-zero exit (same code family as Go's) and prints a one-line error naming the missing manifest when its manifest is missing; stdout stays grep-friendly for the gate (`FAIL: <pkg> missing <manifest>` or the Go-wrapper spelling).
- A tree with every manifest present produces the same output and exit code as today (no regression on the normal path); the suite PASS rows are unchanged for present languages.
- A test (hermetic shell test) pins the behavior for each of the six.

## Scope

### Included

- `typescript/run-suite.sh`, `python/run-suite.sh`, `rust/run-suite.sh`, `csharp/run-suite.sh`, `java/run-suite.sh`, `cpp/run-suite.sh` (one wrapper per package).
- A hermetic test (shell under `tests/` or wherever the project puts suite tests) that removes the manifest in a temp copy and asserts the exit code and the error line.
- Owns (exclusive write): the six `*/run-suite.sh` files above and the test file for this behavior.

### Excluded

- The Go wrapper (already does this).
- Any source change in the six packages (only the wrapper changes).
- Changes to the publish job's selection logic (it continues to call these wrappers).

## Acceptance Criteria

**AC-1: Each wrapper fails when its manifest is missing**
Given each of the six packages with its manifest removed in a temp copy
When `./run-suite.sh <pkg>` runs
Then the exit code is non-zero (match Go's conventional code where sensible) and stdout names the missing manifest; printed PASS rows for that package 0.

**AC-2: Each wrapper passes when the manifest is present**
Given a clean checkout (every manifest in place)
When `./run-suite.sh <pkg>` runs
Then the exit code and PASS rows match the loop 24 close output for that package; regressed rows 0.

**AC-3: AC-15 wording follows the behavior**
Given the AC-15 wording in `_docs/00_problem/acceptance_criteria.md` and the publish-gate task plan
When read
Then the text says `run-suite.sh` fails for a missing language manifest (not skips), so AC-15 cannot be reached by a false green.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | each of the six with its manifest removed | non-zero exit; error line | |
| AC-2 | each of the six on a clean tree | PASS rows unchanged | |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | temp copy of each package, manifest removed | `./run-suite.sh <pkg>` | non-zero exit, error line, 0 PASS rows for the package | |
| AC-2 | clean tree | `./run-suite.sh <pkg>` | unchanged PASS output | |
