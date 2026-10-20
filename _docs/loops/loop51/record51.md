# Autodev loop record — loop 51

loop: 51
branch: dev
plan_artifact: _docs/loops/loop51/plan51.md
tasks_shipped: [AZ-2752, AZ-2753]
decisions:
  - agent: hopper hit wave A of epic AZ-2750 (handoff51); AZ-2752 then AZ-2753, in sequence (one directory)
  - agent: the table keeps the C++ preorder shape (`span`), but references are resolved where they are used, so a scheme stays plain `&[Field]` data; walkers take `&dyn Row`
  - owner 2026-10-20: base flash limit raised from 8,192 B to 16,384 B (option A of one question, recommended) when the image reached 11,028 B
  - agent: dictionaries moved from AZ-2753 to AZ-2754 (keys are strings; order is compared on decoded text)
  - agent: a `list` takes the next order id in the core (the row needs a key); a round limit counts per container where it stands (no per-field counter without a heap)
leftovers:
  - `_docs/02_tasks/todo/AZ-2754` to `AZ-2757` (unclaimed); AZ-2754 holds dicts now (AC-5, re-estimate at intake). Waves in `handoff52.md`
  - C++ core: a `when` whose source sits in a false `when` is matched, so pack writes a body its own unpack refuses (`21 00 05`, TrailingBytes); not a ticket yet (handoff52)
  - security Low L51-1 (CPU grows with the square of the scheme size) and the two skipped review findings (flag byte scan, flag bit position per read): resolve references once if a real scheme gets large
  - stack 472 of 512 B on the flat probe; a nested probe in AZ-2757
  - owner: size limits for text/ecc/session; CS-D5; first `v*` / `go/v*` tags; F44
  - Jira: AZ-2752, AZ-2753 In Testing; epic AZ-2750 open
smoke: PASS (agent run 9/9 at 92d2cdd, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop51/smoke51.md
assessment_artifact: _docs/loops/loop51/assessment51.md
step11: RESULT 4 passed, 0 failed, 456 s at 92d2cdd (rust, rust-embedded, ring, publish-gate)
review: `/code-review` high, 9 findings, 7 fixed, 2 skipped (efficiency, same as L51-1), 0 High
security: PASS, 1 Low (L51-1), `_docs/05_security/nostd_review_loop51.md`
retro: _docs/06_metrics/retro_2026-10-20_loop51.md
loop_end_merge: main
