---
loop: 26
branch: dev
---

# Swift in the CI suite

**Task**: AZ-2521_swift_ci_suite
**Name**: Swift in the CI suite
**Description**: CI runs the Swift suite on every push and pull request, in a `swift` compose service on `swift:6`.
**Complexity**: 3 points
**Dependencies**: AZ-2513
**Component**: swift
**Tracker**: AZ-2521
**Epic**: AZ-2223

## Problem

AC-11: CI must run every language's tests on 100% of pushes; Swift is not in the suite. The root `Package.swift` is also what every Swift consumer resolves, so a broken manifest must fail CI on the push that breaks it.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-9; contributes to SW-5 (60 s fuzz step), SW-8 (speed in a release build), SW-11 (dependency check), SW-14 (thread sanitizer run); scenario S11 in part: the package builds on Linux).

## Outcome

- `run-suite.sh swift` checks the golden row, runs `swift build -c release` with warnings as errors, `swift test` (verbose), the thread-sanitizer run, the speed test in a release build, a 60 s fuzz step and the one-dependency check, and writes one report row.
- The scaffold job runs the `swift` service with the seven.

## Scope

### Included

- `run-suite.sh` `swift` branch guarded by `Package.swift` and `swift/`; `docker-compose.test.yml` and `docker-compose.publish.yml` `swift` services on `swift:6`, and the build-only `swift:5.9` compile step (read-only mount in the publish file, build output outside the mounted tree; a named volume for the SwiftPM cache in the test file); the scaffold job's directory check and suite loop; `report-row.test.sh` and `run-suite.test.sh` rows for Swift.
- Owns (exclusive write): `.github/workflows/run-suite.sh`, `.github/workflows/run-suite.test.sh`, `.github/workflows/test.yml` (scaffold job only), `.github/workflows/report-row.test.sh`, `docker-compose.test.yml`, `docker-compose.publish.yml`

### Excluded

- The ring job (AZ-2522)
- publish (AZ-2523)

## Acceptance Criteria

**AC-1: Suite runs (SW-9)**
Given a push or pull request
When the scaffold job runs
Then the `swift` service runs `run-suite.sh swift` on `swift:6`; a failing Swift test fails the job; `test-results/report.csv` gains one `swift suite` row

**AC-2: Quality gates (SW-9, SW-5, SW-8, SW-11, SW-14)**
Given the Swift tree
When `run-suite.sh swift` runs
Then `swift build -c release` reports 0 warnings (warnings are errors), `swift test` passes, the thread-sanitizer run reports 0 races, the release-build speed test is ≤ 1 s, the fuzz step runs ≥ 60 s with 0 traps, and the built graph holds exactly 1 direct package dependency (`swift-crypto`, plus what it requires) with 0 unsafe flags and 0 C targets of the package's own

**AC-4: Swift 5.9 compile (SW-9, SW-10)**
Given the Swift tree and a `swift:5.9` image
When `run-suite.sh swift` runs its build-only step (`swift build`, no tests, no warnings-as-errors beyond the package's own)
Then the package builds on Swift 5.9 (the manifest's minimum) with exit 0; a feature newer than 5.9 fails the step. Owner ruling 2026-10-14

**AC-3: Absent tree (SW-9)**
Given a tree without `Package.swift` or without `swift/`
When `run-suite.sh swift` runs
Then it fails as for the other languages (guarded by the manifest), proven by `run-suite.test.sh`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-3 | `run-suite.test.sh` swift rows | pass |
| AC-4 | `run-suite.test.sh` row for the 5.9 step (image name from `tool-pins.txt`, step present, runs after the main build) | pass |
| AC-1 | `report-row.test.sh` eight services | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `docker compose -f docker-compose.test.yml run --rm swift` | the Swift suite | exit 0 | AC-11, SW-9 |

## Constraints

- ADR-001: no generator, no other package imported. Unsafe flags 0 in `Package.swift`: warnings-as-errors and complete strict-concurrency checking are passed by the suite on the command line, never written into the manifest (an unsafe flag makes the package unusable as a dependency).
- Swift 6.3.3 runs on the owner's Mac (`swift test`); the suite is the `swift:6` container, as CI runs it. Tests run verbose, never quiet.
- Errors are thrown as the typed `PackbinError`; a trap in any step fails the step.

- From AZ-2513 (loop 26): the tests use swift-testing, so the `swift:5.9` step is `swift build` of the library only (never `swift build --build-tests`/`swift test`). `swift test -c release --filter SpeedTests` runs as its own step (local release figure: typed 0.37 s alone, 0.53 s inside the parallel run; Linux may be slower; if it nears 1 s, fill typed rows from the accessors directly). The Bool-versus-integer split of Foundation `NSNumber` (`__NSCFBoolean` vs `__NSCFNumber` on Darwin) is verified on macOS only: a failing JSON-bool test in the first `swift:6` run is expected-risk, report it, do not skip it.

## Risks & Mitigation

**Risk 1: Shared files**
- *Risk*: `test.yml` is also edited by AZ-2522 (ring job).
- *Mitigation*: This task edits only the scaffold job; AZ-2522 only the ring job; the parent checks the diff at each join.

**Risk 2: Flags reach the dependency**
- *Risk*: Command-line compiler flags apply to every target, so `swift-crypto` warnings under warnings-as-errors or strict concurrency would fail a build that has 0 Packbin warnings.
- *Mitigation*: The 0-warnings count is for the `Packbin` targets; a dependency warning is reported to the parent, not silenced.

**Risk 3: Network**
- *Risk*: The first resolve pulls `swift-crypto` from GitHub; a network failure looks like a test failure.
- *Mitigation*: The exact pin in `Package.resolved` and the named cache volume; a resolve failure is reported as such in the report row.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| SW-9 builds only with `swift:6`, while the manifest admits 5.9 toolchains (see AZ-2513) | owner ruling 2026-10-14: the 5.9 compile step is AC-4 | resolved | Medium |
