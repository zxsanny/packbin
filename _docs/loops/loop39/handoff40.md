---
---
# Loop 40 handoff (written 2026-10-18 at the close of loop 39)

Read `_docs/loops/loop39/record39.md` and `_docs/loops/loop38/record38.md`.

## State
- Loops 35 to 39 are on `origin/dev`; `main` is not pushed and no tag exists. `loop_end_merge: main` in `ci_cd_pipeline.md` would fast-forward `origin/main` at each close; loops 37 to 39 ran the `dev` push only.
- Owner-run and still open: `/feature-assess`, `/security` (AZ-2666), the retrospective of loops 35 to 39, F44, the first tags. The Jira epic AZ-2677 is still To Do.

## Candidate work
- Owner decisions: the default correction limit (0, detect only), the 254-byte limit, and whether the Rust `DispatchHandler::parity()` stays a defaulted method.
- Loop 39 review Lows (record39 leftovers): the duplicate-type vs not-open check order (TypeScript, C#), the empty scheme list spending a position (Swift, Rust). About 2 points.
- A CI run to measure the `test.yml` median (AZ-2689 AC-3); ESP32 and Pico builds with ECC on.
- Real messages (D5): needs 100 to 200 messages from the owner.
- AZ-2068 (AVR build, stretch) is the only unclaimed spec in `todo/`.
