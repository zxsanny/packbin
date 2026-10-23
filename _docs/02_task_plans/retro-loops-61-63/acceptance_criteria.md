# Acceptance criteria: retrospective of loops 61 to 63

Project ACs are inherited where they apply (no source change, so the wire format, budgets and test ACs are not exercised). Rows below are this loop's.

**AC-1: Report** — `_docs/06_metrics/retro_2026-10-23_loop64.md` exists, has the sections of `templates/retrospective-report.md` (metrics, what the data says, improvements), covers loops 61, 62 and 63 in one metrics table of 3 rows, and compares against `retro_2026-10-22_loop60.md` (which of its 3 improvements held).

**AC-2: Figures from artifacts** — Every number in the metrics table is read from an artifact or a command and none is estimated: commits per loop from `git log` by the `Loop:` trailer or the commit range (expected 2, 4, 5), tasks and points from the task specs in `_docs/02_tasks/done/` (expected 3 tasks, 8 points), step 11 results from the records (0 passed / 14 skipped, 5 / 9 / 426 s, 5 / 9 / 395 s), flash and stack figures from the records (8,032 B to 7,808 B to 7,724 B; stack 504 B to 496 B).

**AC-3: Lessons** — `_docs/LESSONS.md` gets 1 to 3 new lines (category and `Source:` line as the skill formats them) and holds at most 15 entries; a lesson that repeats an `AGENT_GOTCHAS.md` or LESSONS line goes to `AGENT_GOTCHAS.md` as one line instead of a third bullet.

**AC-4: Improvements** — The report states exactly 3 improvements, each a concrete rule, file or command (not a platitude), ranked by impact.

**AC-5: No source change** — `git diff --stat <Start commit>..HEAD` at close names only files under `_docs/` (0 files outside it), and `git status` is clean after the close commit.

**AC-6: Tracker untouched** — The two Jira leftovers keep their payload (the loop 64 record is added to the Jira line); no task is created, so no new `AZ-PENDING` spec appears.

**AC-7: Smoke** — `_docs/loops/loop64/smoke64.sh` (one script, per-step PASS/FAIL) checks AC-1 to AC-6 and prints PASS for every step.
