# Feature: percentage docs and device run (loop 98)

Handoff for decompose, written by new-task Step 2b; the estimate is 8 points in three tasks (docs 2, C++ device run 3, Rust device run 3), none above 5. Intake: `problem.md`, `acceptance_criteria.md`, `scenarios.md`.

## Scenarios
See `scenarios.md` (S1 to S12, all confirmed).

## Fit decisions
- No collision with today's behavior: the docs add text; the device runs add tests and no package behavior. The only collision is the flash and stack pins (concern 1 of `problem.md`): a pin moves only with the owner's yes.
- Epic: none (same as loops 96 and 97).
