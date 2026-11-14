---
loop: 126
branch: dev
---

# Dart: a scheme nested deeper than 256 levels is refused when it is built

**Task**: AZ-4301_scheme_depth_dart
**Name**: Dart: a scheme nested deeper than 256 levels is refused when it is built
**Description**: Dart refuses, when a scheme is built, a nesting depth above 256, by the shared contract, before any walk that recurses.
**Complexity**: 2 points
**Dependencies**: AZ-4294_scheme_depth_hostile_cases_and_readme
**Component**: dart
**Tracker**: AZ-4301
**Epic**: AZ-4133

Owner decision D18 (2026-11-14). Contract: `_docs/02_document/contracts/library/scheme-depth.md`. Evidence: `_docs/06_metrics/scheme-depth-probe_2026-11-14.md`. Problem: `_docs/02_task_plans/scheme-depth-limit/problem.md`.

## Problem

Today (`StackOverflowError` at build from 5,000 levels (1,000 works): the loop 113 finding) there is no depth limit. The owner decided on one limit of 256 levels for all nine packages, refused when the scheme is built, with the package's scheme error.

## Outcome

- A scheme nested deeper than 256 levels cannot be built in Dart: the package's scheme error with the contract's text; nothing is packed.
- A scheme at 256 levels builds, packs and unpacks as before, for every container kind the package can nest, at the host's default stack.
- The package answers the four shared hostile cases like the other eight.

## Scope

### Included
- The depth check (`dart/lib/src/build.dart` (`scheme()`), before `checkNesting` (`dart/lib/src/checks.dart:90`)); error: a `PackbinException` of kind `schemeError`.
- The package's hostile loader (the four new cases) and its own tests.
- `scripts/probes/scheme-depth/dart/` only if a line cannot be produced otherwise.

### Excluded
- Other packages; the root `README.md`, `fixtures/hostile/`, the contract (AZ-4294).
- Pack and unpack; the wire format; any other limit.

## Acceptance Criteria

**AC-1: Deeper than 256 is refused when the scheme is built**
Given a chain of 257 nested `when`s, a chain of 257 nested groups, and (where the package has the form) a chain of 257 list or dict element rows
When the scheme is built
Then it is refused with a `PackbinException` of kind `schemeError` carrying the contract's text; nothing is packed; and a chain of 1,000 and of 50,000 is refused the same way within 5 seconds with no stack error, crash or hang

**AC-2: 256 levels still work**
Given a chain of 256 levels of each kind in `when`, `nested` (same name at every level is allowed), list and dict element rows via `nested`
When the scheme is built and a value is packed and unpacked at the host's default stack (no raised recursion limit, no big-stack thread)
Then it builds, packs the bytes it packed before and unpacks to the same value

**AC-3: The shared cases**
Given `fixtures/hostile/cases.txt`
When the package's hostile loader runs
Then `construct_depth_when_257` and `construct_depth_group_257` give `scheme_error`, and `pack_depth_when_256` (`010107`) and `pack_depth_group_256` (`0107`) pack those bytes; a case the package cannot write is named as skipped with its reason

**AC-4: The probe**
Given `bash scripts/probes/scheme-depth/run.sh dart`
When it runs
Then the 1,000, 5,000 and 50,000 lines are `refused` (the Rust heap-free API may print its own `MAX_FIELDS` refusal at 50,000), no `threw`, `crashed` or timeout line, each case under 5 seconds

**AC-5: Nothing else moves**
Given the package's whole suite
When it runs the way CI runs it
Then it passes with the same count plus the new tests; no existing test was changed to keep the check (a scheme of the tests deeper than 256 is reported)

## Non-Functional Requirements

- The check is O(size of the scheme) with no recursion and no allocation proportional to the depth beyond a small constant (device pins for Rust and C++ hold or are reported).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 257 / 1,000 / 50,000 chains of each kind | the package's scheme error with the contract's text, quickly |
| AC-2 | 256 chains of each kind: build, pack, unpack | same bytes and value, no stack error |
| AC-3 | the hostile loader | the four cases pass |
| AC-1 | 256 and 257 boundary per kind | 256 builds, 257 refused |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | the probe | `bash scripts/probes/scheme-depth/run.sh dart` | refused lines, under 5 s each | O(size) |
| AC-5 | the suite | `cd dart && dart analyze && dart format --output=none --set-exit-if-changed . && dart test` | passes | — |

## Constraints

- Contract decides; this spec says where. The check is first in the scheme build and iterative. No new public name, error kind or dependency.
- `scheme()` takes fields that are plain values built before it: the nesting exists as a tree when `scheme()` is called; measure it with an explicit stack.

## Risks & Mitigation

**Risk 1: 256 levels of one kind do not fit the default stack**
- *Risk*: the package recurses in pack or unpack, so 256 levels of a heavy kind may overflow.
- *Mitigation*: AC-2 measures it; a failing kind is reported with the depth that works (the limit is the owner's), not worked around with a bigger stack.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A scheme deeper than 256 that built before stops building | owner, D18 (2026-11-14); the deepest known real scheme has a handful of levels | resolved | Low |
