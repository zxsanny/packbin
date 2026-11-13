---
loop: 121
branch: dev
---

# Dart: wall-clock tests use the load-aware timing helper

**Task**: AZ-4260_dart_timing_helper
**Name**: Dart: wall-clock tests use the load-aware timing helper
**Description**: entries of the hygiene queue item `_docs/02_task_plans/hygiene-loop121/queue_item.md` (loop 121), below; their text is the spec.
**Complexity**: 1 points
**Dependencies**: none
**Component**: dart/test/
**Tracker**: AZ-4260
**Epic**: AZ-4133

Dart only.

Each entry below: its Problem, Outcome, Code sections and Acceptance checks are this task's; an acceptance check that names another package belongs to that package's task. Common: no packet change, every refusal text of a path the entry does not name stays the same, the package suite passes.

## Entry: Dart: use the load-aware timing helper in the wall-clock tests

slug `dart-colliding-keys-timing-helper`; severity low; source: found in loop113 (AZ-4217 fix round: `dart/test/limits/colliding_keys_test.dart` failed once at host load 50, 1,377 ms against `lessThan(1000)`); created 2026-11-12
### Problem
`dart/test/limits/colliding_keys_test.dart` (65,535 colliding keys, two bounds `lessThan(1000)` at about lines 146 and 180) uses fixed wall-clock bounds. In loop 113 it failed once at host load about 50 (1,377 ms) and passed in the final run. The other eight packages use a load-aware helper for every wall-clock check (`_docs/gotchas/timing-bounds-use-load-factor.md`). Dart had none until loop 113, which added `dart/test/support/timing.dart` for its own new cost test.

### Outcome
Every wall-clock assertion of the Dart suite calls the helper; a fixed bound does not fail on a busy host.

### Code sections
`dart/test/limits/colliding_keys_test.dart`, any other `lessThan(` or `Stopwatch` use under `dart/test/` (search), `dart/test/support/timing.dart`.

### Acceptance checks
- `git grep -n -E "lessThan\(|Stopwatch" dart/test` lists only calls inside the helper or tests that use it.
- The suite passes at an idle host and at load above 30 (run twice).

### Needs
none

### Constraints
The nominal bounds stay as they are; the helper scales them by the measured load.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| agent-found hygiene entries; no operator decision outstanding (D14, D15 applied) | agent | accepted-risk | Low |
