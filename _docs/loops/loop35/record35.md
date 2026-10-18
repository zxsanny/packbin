# Autodev loop record — loop 35

loop: 35
branch: dev
plan_artifact: _docs/loops/loop35/plan35.md
tasks_shipped: [AZ-2646, AZ-2647, AZ-2648, AZ-2649, AZ-2650, AZ-2651, AZ-2652, AZ-2653, AZ-2654, AZ-2655, AZ-2656, AZ-2657, AZ-2658]
leftovers:
  - /feature-assess, the security audit (a new decoder reads untrusted bytes in 8 languages) and the retrospective were skipped by the owner and carry to loop 36 (`handoff36.md`)
  - review35.md: 7 of 9 findings carried (a lone-string encode once per pack call instead of five memos; the 1 s speed bound is asserted only in release for Rust and Swift; a guard on Scratch; CompactTextTests.cs 620 lines; refusal kinds not exposed; the unrequested get_number/put_number and Field::eq edits; research/bench.py 688 lines)
  - D5: the tables come from Tatoeba sentences and synthetic numbers; retraining on real messages is a wire break, free until the first v* tag
  - Cortex-M4F margins are 60 B flash and 20 B stack (AGENT_GOTCHAS)
  - the 8 fuzz seeds in go/testdata/fuzz/FuzzUnpack still hold old-format bytes (they pass as regression inputs)
  - Jira: AZ-2646 to AZ-2658 stay In Testing (no retrospective, so the Done rule does not apply); epic AZ-2645 stays open until the first tag
  - from earlier loops: F44 (tag ruleset), the first v* and go/v* tags (owner only), AZ-2068 in todo/; main not pushed (owner asked for the dev push only)
smoke: PASS (agent run 8/8 at 1af9cf0, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop35/smoke35.md
review_artifact: _docs/loops/loop35/review35.md
loop_end_merge: main (not executed: the owner asked for the dev push only)
