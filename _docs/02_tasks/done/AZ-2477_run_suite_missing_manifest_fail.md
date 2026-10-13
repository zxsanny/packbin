---
loop: 25
branch: dev
---

# `run-suite.sh`: the six fail without their manifest (align with Go)

**Task**: AZ-2477_run_suite_missing_manifest_fail
**Name**: `run-suite.sh`: the six fail without their manifest (align with Go)
**Description**: D6 A: `run-suite.sh` for TypeScript, Python, Rust, C#, Java, C++ returns a non-zero exit and names the missing manifest when its manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, `*.csproj`, `pom.xml`, `cpp/CMakeLists.txt` or the project's equivalent) is missing — the Go wrapper's behavior. Today the six skip with a PASS row, which hides a corrupt tree.
**Complexity**: 2 points
**Dependencies**: none
**Component**: `.github/workflows/run-suite.sh` (one script; the six languages are branches of one `case`)
**Tracker**: AZ-2477
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

- `.github/workflows/run-suite.sh`: a `missing_manifest` helper and an `else` branch for csharp, typescript, python, rust, cpp and java (Go reuses the helper).
- `.github/workflows/run-suite.test.sh`: a bare tree per language (exit non-zero, the message names the manifest, one FAIL row, no tool ran), an empty `csharp/` directory, and the manifest present with fake tools (csharp, rust, cpp, java; TypeScript's `bash -lc` cannot take a fake `npm`).
- Owns (exclusive write): those two files; `_docs/04_deploy/ci_cd_pipeline.md` (one sentence).

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

**AC-3: AC-15 is untouched**
Given `publish-gate.sh` decides `absent <lang>` itself and no publish script calls `run-suite.sh`
When the six fail on a missing manifest
Then AC-15 (a language missing from the tagged tree publishes 0 packages) is unchanged; the CI doc says which script decides what.

(Amended at implementation: the first draft planned six wrappers and an AC-15 wording change; there is one script, and AC-15 does not read it.)

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
