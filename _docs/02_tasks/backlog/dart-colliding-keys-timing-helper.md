---
kind: queue-item
order: 500
source: found in loop113 (AZ-4217 fix round: `dart/test/limits/colliding_keys_test.dart` failed once at host load 50, 1,377 ms against `lessThan(1000)`)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Dart: use the load-aware timing helper in the wall-clock tests

## Problem
`dart/test/limits/colliding_keys_test.dart` (65,535 colliding keys, two bounds `lessThan(1000)` at about lines 146 and 180) uses fixed wall-clock bounds. In loop 113 it failed once at host load about 50 (1,377 ms) and passed in the final run. The other eight packages use a load-aware helper for every wall-clock check (`_docs/AGENT_GOTCHAS.md`, lines on timing bounds). Dart had none until loop 113, which added `dart/test/support/timing.dart` for its own new cost test.

## Outcome
Every wall-clock assertion of the Dart suite calls the helper; a fixed bound does not fail on a busy host.

## Code sections
`dart/test/limits/colliding_keys_test.dart`, any other `lessThan(` or `Stopwatch` use under `dart/test/` (search), `dart/test/support/timing.dart`.

## Acceptance checks
- `git grep -n -E "lessThan\(|Stopwatch" dart/test` lists only calls inside the helper or tests that use it.
- The suite passes at an idle host and at load above 30 (run twice).

## Needs
none

## Constraints
The nominal bounds stay as they are; the helper scales them by the measured load.
