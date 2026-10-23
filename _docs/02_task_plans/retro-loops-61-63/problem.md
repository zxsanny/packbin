---
loop: 64
branch: dev
---

# Retrospective of loops 61 to 63 (loop 64)

Source: `_docs/loops/loop63/handoff64.md` action 2 ("a retro is due, loops 61 to 63 since the last one"). The hopper was empty; the owner picked the work in chat on 2026-10-23 (AskUserQuestion, recommended option): "Retrospective loops 61-63". The last retro is `_docs/06_metrics/retro_2026-10-22_loop60.md` (loops 56 to 60).

## Problem

Three product loops ran since the last retro, all on one C++ budget question (Cortex-M4F flash and stack of the core): loop 61 measured the pack-side `held_of` and did not keep it, loop 62 dropped `Field::count` (flash 8,032 B to 7,808 B), loop 63 found an 84 B saving in `pack.cpp` (7,808 B to 7,724 B) and dropped `held_of` again. Nobody has yet read the three together for process findings: the estimates against the measures, the review and test cost, the chain of "measure, do not keep".

This is a short loop with no code change (`worktree-isolation.md` §Short loop on launcher): run `retrospective/SKILL.md` in on-demand mode over loops 61 to 63, write the report and the lessons, close.

## Code sections / UI locations for this loop

No UI, no source code. The owner's pick named the work ("Retrospective loops 61-63": reads the loop records 61 to 63 and writes the retro and the LESSONS lines).

| Work | Place |
|------|-------|
| Inputs (read only) | `_docs/loops/loop61/` to `_docs/loops/loop63/` (records, plans, assessments, handoffs), `_docs/03_implementation/batch_*_loop62_report.md`, `batch_*_loop63_report.md`, `_docs/02_tasks/done/`, git log by `Loop:` trailer, `_docs/06_metrics/retro_2026-10-22_loop60.md` |
| Output | `_docs/06_metrics/retro_2026-10-23_loop64.md`, `_docs/LESSONS.md`, `_docs/AGENT_GOTCHAS.md` (only for a repeat) |

Excluded: every file outside `_docs/`; the Jira leftovers; the owner items.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Jira connector absent: no tracker write, two leftovers wait for a replay; this loop creates no task, so no new key is owed | `tracker.md` Tracker Availability Gate | accepted-risk | Low |
| `AGENT_GOTCHAS.md` is already longer than one page (a few very long lines); the retro adds a line only for a repeated mistake, and does not restructure the file | retrospective Step 4 | accepted-risk | Low |
| Loops 61 to 63 had no per-batch review (owner preference) and loop 61 had no source change: the review and finding metrics are thin by design, the report says so instead of inventing a rate | `one-total-review-and-test` (owner preference) | accepted-risk | Low |
