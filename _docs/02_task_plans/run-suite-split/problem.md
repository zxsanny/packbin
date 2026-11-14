---
loop: 124
branch: dev
source: _docs/02_task_plans/run-suite-split/queue_item.md
---
# Problem: run-suite.sh is at the 500-line cap

The owner picked the held hygiene entry `run-suite-split` on 2026-11-14 ("Run the split"), so the item is operator-made. `.github/workflows/run-suite.sh` reached 500 lines in loop 123. Short loop on the launcher (one file split, no behaviour change): no new-task, no P1 plan file beyond the spec, no feature-assess.

## Outcome
`run-suite.sh` under 400 lines; Go, Rust and C++ helpers in sourced files; every suite runs the same steps.
