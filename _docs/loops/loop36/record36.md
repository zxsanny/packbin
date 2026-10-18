# Autodev loop record — loop 36

loop: 36
branch: dev
plan_artifact: _docs/loops/loop36/plan36.md
tasks_shipped: [AZ-2664, AZ-2665]
leftovers:
  - AZ-2666: the formal `/security` audit of the compact text decoders is reserved for the owner; a focused decoder review (`_docs/05_security/compact_text_decoder_review_loop36.md`, no High or Critical finding) is the stand-in; the ticket stays In Progress
  - `/feature-assess` and the retrospective of loops 35 and 36 are owner-run skills and not done
  - review35.md Low findings still carried: a guard on `Scratch` (786 KB at 65,535 characters), `CompactTextTests.cs` at 620 lines, refusal kinds not exposed, the unrequested `get_number`/`put_number`/`Field::eq` edits, `research/bench.py` at 688 lines
  - CI: the Rust release step may add minutes to the `csharp rust` suite job; read the first CI run
  - `handoff36.md` still describes the state before the loop 35 close; the loop 37 handoff supersedes it
  - D5 real messages (any retraining is a wire break, free until the first v* tag); F44 and the first v*/go/v* tags (owner only); AZ-2068 in todo/; main not pushed
smoke: PASS (agent run 5/5 at bd9cc89, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop36/smoke36.md
loop_end_merge: main (not executed: the owner asked for the dev push only)
