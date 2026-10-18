# Loop 36 handoff (written 2026-10-18 while loop 35 was open)

Read `_docs/loops/loop35/review35.md`, `_docs/02_task_plans/compact-strings/{research_report,acceptance_criteria,feature-description}.md` and `_docs/02_document/contracts/library/compact-text.md`.

## State
- Epic AZ-2645, tasks AZ-2646 to AZ-2658 (57 points) are committed on `dev` (not pushed) and In Testing in Jira. Step 11 passed at `a9cabf1` (9 stages, 4 unchanged-skipped, scaffold only on its serial retry; the first run at `f553ef9` had passed the rest and failed C# and the ring, both fixed).
- Not done: `/feature-assess`, the security audit, the retrospective, the loop smoke and the loop close (record, push `dev`). The first two and the retrospective are reserved for the owner to run.

## Candidate work
- The seven review findings carried in `review35.md` (a lone-string encode once per pack call; enforce the 1 s bound in debug CI for Rust and Swift; a guard on `Scratch`; split `CompactTextTests.cs`; expose refusal kinds).
- Real messages to retrain the tables (D5): any retraining is a wire break; the owner said to send 100 to 200 messages before the first tag. Until a `v*` tag exists the break is free.
- CRC for the whole message (separate task).
- Cortex-M4F margins are now 60 B flash and 20 B stack (`_docs/AGENT_GOTCHAS.md`).
- Owner only: F44 (tag ruleset), the first `v*` and `go/v*` tags.
