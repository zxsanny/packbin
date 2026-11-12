# Batch Report

**Batch**: 1 (loop 112)
**Tasks**: AZ-4206_repeat_followed_by_a_field
**Date**: 2026-11-12

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4206_repeat_followed_by_a_field | Done | 28 new files under `scripts/probes/repeat-followed-by-field/` (nine probes with their `run.sh`, the runner, the rule-count tool, the README); the findings; the contract `repeat-last.md`; 10 specs and the feature folder; no package source | the runner: 85 lines, exit 0, every `control` line `same`, three runs byte-identical; rule count: 4 refused of 77,266 built | None |

How it was done: the TypeScript probe first (the reference bytes), then the other eight packages by four workers, two packages each, disjoint folders. A sixth shape (`f`, two repeats in a row) was added during the batch because TypeScript read it back as other values with no error; all nine do.

AC coverage: AC-1 the appendix of `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` is the run, copied by script (the smoke compares them); AC-2 the rule, the four options and the measured count are in the same file, the owner chose "Refuse at build" (2026-11-12); AC-3 epic AZ-4209, AZ-4210 to AZ-4219 in `todo/`, contract `_docs/02_document/contracts/library/repeat-last.md`.

## Code Review Verdict: PASS_WITH_WARNINGS

`_docs/03_implementation/reviews/batch_01_loop112_review.md`: 5 Medium and 15 Low, no Critical or High. 18 fixed before the commit (three "can never print `same`" comparisons, one of them in six probes; the C++ path that showed any constexpr compile failure as a refusal; the rule-count call that ran before the constructor's last checks; README inexactness; shell edge cases), 2 kept with reasons (the C# probe compiles the package sources; the Go probe has one process). The four special claims of the table were confirmed in the package sources.

## Test Suite

- `bash scripts/probes/repeat-followed-by-field/run.sh`: 85 lines, exit 0, 31 to 43 s; 10 of 10 `control` lines `same`.
- `bash scripts/probes/repeat-followed-by-field/rule-count/run.sh`: TypeScript suite in the copy 3,642 of 3,642; 4 schemes refused; 77,266 built, 11 by the ring drivers.
- CI-parity: PASS. `scripts/loop-tests.sh` with the stamps of the last total run (`bb99503`): only `scaffold` is reached by `scripts/**`; `STAGE scaffold: PASS (386s)`, 14 stages unchanged. Run before the review fixes; step 11 repeats it on the committed tree.
- Failed: 0; Skipped: 0.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Two repeats in a row are read back as other values with no error, in all nine packages | AZ-4206 scope (five shapes) | probed as shape `f`; covered by the rule (a second repeat is a field that follows): contract case R5 | clear (the owner's rule: "a second repeat too") |
| 2 | Rust (both APIs) and bound C++ lists cannot have a row as an element, so shapes `b` and `c` cannot be written there | AZ-4206 AC-1 (45 cells) | the cell records the package's refusal of the row; C++ refuses the unbound form by the rule (AZ-4219 AC-5) | clear (the spec's Risk: a cell says why, it is not left empty) |
| 3 | Java and C++ build a repeat inside a `repeat` or `times` round today (README); the other seven refuse it | none | contract case R9: refused at build in Java and C++ too; agent default, flagged `open` Low in AZ-4214, AZ-4219, AZ-4210 | clear by the chosen rule ("the last thing a packet reads"); the owner can overrule it before those tasks start |
| 4 | Schemes that read back for some rows only (one list item, a `when` not taken, a clear flag bit, two `when`s that cannot both be taken) | AZ-4206 flagged concern | refused by the rule; the `when` exception was offered to the owner and not taken; contract case R6 pins it | clear (owner decision 2026-11-12) |
| 5 | The check adds code to the two packages that run on a device | none | a budget in AZ-4218 AC-5 and AZ-4219 AC-6 (256 B of flash, 64 B of stack; above it the owner decides) | clear (owner 2026-10-25: budgets are chip-scale; a pin raise needs a note) |
| 6 | The rule count was measured in TypeScript only; the other eight suites and Archangel's schemes are not counted | AZ-4206 AC-2 ("existing fixtures and golden vectors") | shared fixtures, golden vectors and ring schemes: 0 (measured); each package task counts its own tests; Archangel is the owner's check before the upgrade | clear (the AC asks for the fixtures and vectors) |
| 7 | `scripts/loop-tests.sh` writes a stage's stamp only when the tree is clean, and step 11 always runs with loop documents uncommitted, so the default plan re-runs stages that passed (9 of 15 here) | none (process) | step 11 seeds `LOOP_TESTS_STAMPS` with the last total run, as the loop 80 note says; a change of the script (a dirty `_docs/` does not block a stamp) is a candidate for a later loop | unclear only as to priority; not part of this feature |

## Commit

`[AZ-4206] Probes of a repeat that is not last, findings, rule tasks` — body: one line + `Loop: 112`.

## Next Batch: All tasks complete (AZ-4210 to AZ-4219 are unclaimed, for the next loop)
