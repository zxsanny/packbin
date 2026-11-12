# Implementation report: repeat-followed-by-a-field (loop 112)

**Task**: AZ-4206 (3 points, probe and decision). **Batches**: 1. **Date**: 2026-11-12.

## What was delivered

- `scripts/probes/repeat-followed-by-field/`: one probe per package (TypeScript, C#, Python, Rust map form and heap-free API, Java, C++, Go, Swift, Dart), each with a `run.sh` that builds in a temporary directory and writes nothing into the checkout; `run.sh` runs them all (85 lines, about half a minute); `rule-count/` counts the TypeScript schemes a build-time rule would refuse.
- `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`: the outcome matrix (10 forms by 8 shapes), the packets, the proposed rule with four options, the measured cost, and the run as an appendix.
- The owner's decision (2026-11-12): refuse at scheme build.
- `_docs/02_document/contracts/library/repeat-last.md`: the rule as a contract (refused cases R1 to R9, still-building cases K1 to K5 with packets run in TypeScript).
- Epic AZ-4209: `todo/AZ-4210` (shared hostile cases and README, 2 points) and `todo/AZ-4211` to `AZ-4219` (one per package, 27 points); `_docs/02_task_plans/repeat-must-be-last/` (feature description, scenarios).

## Result in three lines

- A field after a repeat (top level, nested row, under `when`, under `flags`): all nine packages build it, pack the same bytes and refuse them on unpack.
- A repeat inside a list or dict element row: seven do the same; Rust and C++ cannot have a row as an element.
- Two repeats in a row: all nine read the packet back as other values with no error.

## Not done here

- The rule itself (excluded by the task): epic AZ-4209.
- The count of refused test schemes in the eight packages other than TypeScript; Archangel's schemes.

## Deferred / follow-up

- AZ-4210 to AZ-4219 (next loop; AZ-4210 first, then the packages in waves of four).
- The stamp rule of `scripts/loop-tests.sh` (batch report, row 7).
