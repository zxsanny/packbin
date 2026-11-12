# Feature assessment — loop 112

loop: 112
feature: repeat-followed-by-a-field
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-12
**Implement pass**: batch 01 (`_docs/03_implementation/batch_01_loop112_report.md`, commit `5bac143`), completeness `_docs/03_implementation/implementation_completeness_loop112_report.md`, review `_docs/03_implementation/reviews/batch_01_loop112_review.md`
**Verdict**: COMPLETE — 13 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

The task is a probe and a decision, so "production code path" below is the committed probe that produced the cell; no package source changed. `scenarios.md` is absent for AZ-4206 (the spec was written straight into `todo/` in loop 111); the rows come from the spec, the batch discoveries and a re-walk of what the probes added.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A field after a repeat at the top level, in nine packages | covered | AC-1; shape `a`, 10 lines of the run (`built`, `01050609`, `refused`); `scripts/probes/repeat-followed-by-field/*/` | spec Included (a) |
| S2 | A repeat in a list element row | covered | AC-1; shape `b`: 7 packages `built` and `refused`, Rust (two APIs) and bound C++ refuse the row, C++ `b-unbound` builds; the cells say why | spec Included (b) |
| S3 | A repeat in a dict element | covered | AC-1; shape `c`, as `b` | spec Included (c) |
| S4 | A repeat in a nested row followed by a field | covered | AC-1; shape `d`, 10 lines; the README of the probes says how `d` is written per package | spec Included (d) |
| S5 | A repeat under `flags` or `when` followed by a field | covered | AC-1; shapes `e-when` and `e-flags`, 10 lines each | spec Included (e) |
| S6 | The table records build, pack hex and unpack per cell, read from a run | covered | AC-1; the appendix of `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` is the run, copied by script; three runs byte-identical; the smoke compares the table with a fresh run | spec AC-1 |
| S7 | One rule for all nine is proposed with the evidence | covered | AC-2; the findings' Proposed rule and the four options; the owner chose "Refuse at build" (2026-11-12) | spec AC-2 |
| S8 | The existing fixtures and golden vectors the rule would refuse are listed (expected 0, measured) | covered | AC-2; `rule-count/run.sh`: 0 shared fixtures, golden vectors or ring schemes, 4 of TypeScript's own test schemes, 77,266 schemes built | spec AC-2 |
| S9 | After the decision the implementation tasks exist in `todo/` with tracker ids | covered | AC-3; epic AZ-4209, `todo/AZ-4210` to `AZ-4219`, contract `repeat-last.md`, `_docs/02_task_plans/repeat-must-be-last/` | spec AC-3 |
| S10 | The repeat wire format changes, or the rule is implemented in this task | out-of-scope | spec `### Excluded`: "Changing the repeat wire format (no count is added)", "Implementing the rule in this task" | spec Excluded |
| D1 | Two repeats in a row are read back as other values with no error | covered | shape `f`, 10 lines `differs`; the owner's rule names it ("a second repeat too"); contract case R5 | batch 01 discovery 1 |
| D2 | Rust and bound C++ lists cannot have a row as an element | covered | the cells and notes 1 and 2 of the findings; confirmed in the sources by the review; AZ-4218 AC-1, AZ-4219 AC-5 | batch 01 discovery 2 |
| D3 | Java and C++ build a repeat inside a round today | covered | contract case R9 and its Decisions line (agent default from the chosen rule, the owner can overrule it); AZ-4214 AC-5, AZ-4219 AC-5; flagged `open` Low in those specs and AZ-4210 | batch 01 discovery 3 |
| D4 | Schemes that read back for some rows only stop building under the rule | covered | the findings' "Schemes of this kind that do read back today" and option B; owner decision; contract case R6; TypeScript lines `x-one-item`, `x-exclusive-when` | batch 01 discovery 4 |

Discoveries 5 (the device budget) and 6 (the other eight suites are not counted) are recorded in the follow-up specs (AZ-4218 AC-5, AZ-4219 AC-6; AC-4 of each package task) and in the findings' "Not measured"; they are not behaviours of this task.

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- The probes on Linux: they were run on the project's Mac only and are not part of CI; `swift/run.sh` and `cpp/run.sh` have a macOS branch for the SDK path.
- Archangel's schemes (another repository): the owner checks them before the upgrade.

### Harness gaps

- `scripts/loop-tests.sh` writes a stage's stamp only on a tree that is clean apart from the state file, so the default plan re-runs stages that passed (batch 01 discovery 7); step 11 seeds the stamps of the last total run.
