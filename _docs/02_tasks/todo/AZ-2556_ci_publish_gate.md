---
loop: 27
branch: dev
---

# CI publish gate: Swift position stand-in and Swift stage sanitizer scope

**Task**: AZ-2556_ci_publish_gate
**Name**: CI publish gate: Swift position stand-in and Swift stage sanitizer scope
**Description**: The `publish gate` step of `test.yml` passes on a Linux runner whose Swift differs from the pin, and the Swift stage costs less time.
**Complexity**: 3 points
**Dependencies**: AZ-2522, AZ-2523
**Component**: ci
**Tracker**: AZ-2556
**Epic**: AZ-2223

## Problem

After the loop 26 close push `test.yml` was red on `dev`. The `ring` job (fixed in `aefaf37`) and then the `publish gate` step failed on the runner: `ring-swift.sh` reads `swift --version` on Linux, the test's stand-in `swift` printed nothing, and the position program built in the `swift:6.3.3` image instead of using the stand-in (the Mac returns before the version check, so it never showed). The Swift stage was also slow: the thread-sanitizer test run took 368 s of 651 s.

Feature ACs: `_docs/02_task_plans/ci-publish-gate/acceptance_criteria.md` (CG-1 to CG-8). Cause and evidence: `_docs/04_deploy/reports/deploy_status_report.md`.

## Outcome

- The Swift position test answers `--version` with the pinned Swift, so the gate passes on a runner with another Swift.
- The thread-sanitizer run covers `ConcurrencyTests`, `SessionTests` and `SessionHostileTests`, and fails by name when one is missing from the test list.
- `run-suite.sh` prints the seconds of every step.

## Scope

### Included

- `.github/workflows/publish-swift-gate.test.sh` (`sw_write_ring_swift`), `.github/workflows/run-suite.sh` (`run`, `swift_sanitized`), `.github/workflows/run-suite-swift.test.sh` (fake `swift` lists the three suites; expected call list; case S6b), the status report and the loop 27 feature folder.

### Excluded

- A named build-cache volume and a shared consumer cache (measured: no CI gain, and the shared cache contradicts the AC-2 fresh-state mutation proofs); `swift/**` sources; any tag or registry upload.

## Acceptance Criteria

**AC-1: Gate green on a differing Swift (CG-1, CG-2, CG-3)**
Given a runner whose Swift is not the pinned 6.3.3
When `test.yml` runs on `dev`
Then `scaffold`, `embedded` and `ring` conclude `success`; the `publish gate` step takes at most 1 500 s and `scaffold` at most 3 000 s; 3 consecutive runs pass the gate

**AC-2: Cause reproduced and named (CG-4)**
Given `swift:6.4.1` on Linux
When `publish-swift.test.sh` runs before and after the stand-in change
Then 9 `position:` failures before, 0 after, all 30 mutants rejected

**AC-3: Sanitizer scope (CG-5)**
Given the Swift stage in the `swift:6.3.3` container
When it runs
Then the stage takes at most 500 s, the plain run is 340 tests in 56 suites, the sanitizer run is the 3 suites, and a missing suite fails the step naming it

**AC-4: Other checks untouched (CG-7, CG-8)**
Given the ring toolchain checks and the tag list
When the loop ends
Then `ring-toolchains.sh` has 0 changed lines, `ring` is under 10 min, and 0 tags and 0 registry uploads exist

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-3 | `run-suite-swift.test.sh` S2 and S6b | the call list has the filtered sanitizer run; a missing `SessionTests` fails by name and the sanitized tests never run |
| AC-2 | `publish-swift.test.sh` position checks | pass with a stand-in that answers `--version` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | push of `dev` | `test.yml` run read from the Actions API | jobs `success`, gate <= 1 500 s | CG-1..3 |
| AC-2 | `swift:6.4.1` container | `publish-swift.test.sh` | exit 0 | CG-4 |
| AC-3 | `docker compose run swift` | the Swift stage | exit 0, <= 500 s | CG-5 |

## Constraints

- Measure before and after; no change on a guess (meta-rule, debugging over contemplation).
- Every shell step ends on its own; a stand-in answers only what the script under test reads.

## Risks & Mitigation

**Risk 1: Sanitizer scope hides a race in another suite**
- *Risk*: a thread-using suite outside the three goes unsanitized.
- *Mitigation*: the library has no lock or mutable shared state (grep of `Sources`), only `ConcurrencyTests` spawns tasks; a new thread-using suite must join the list in `swift_sanitized`.

**Risk 2: The earlier `f30c87e` gate failure has another cause**
- *Risk*: a flake the stand-in fix does not explain.
- *Mitigation*: CG-3 (three green runs) decides; a red run is triaged from its timings.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `f30c87e` gate failure (1 of 2 runs, before `aefaf37`) unexplained | CG-3 | open | Medium |
| Sanitizer scope is a coverage cut | S1 A, owner 2026-10-15 | accepted-risk | Low |
