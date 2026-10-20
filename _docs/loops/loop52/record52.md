# Autodev loop record — loop 52

loop: 52
branch: dev
plan_artifact: _docs/loops/loop52/plan52.md
tasks_shipped: [AZ-2754, AZ-2755]
decisions:
  - agent: hopper hit on wave B of epic AZ-2750 (handoff52); AZ-2754 re-estimated at intake to 8 points (text 5, dictionaries 3); no `/decompose` (already a slice)
  - agent: three batches in sequence (one directory), no per-batch review or test run (owner rule), one total review and one step 11
  - agent: a string kept as on the wire is `Utf8Wire` (the spec's "Packed" is already the bit-packed numbers kind); a dictionary item row holds its key under `DICT_KEY` (= `NO_ID`)
  - agent: the C++ raw memo (AZ-2742) is not ported; AZ-2757 measures it
  - agent: the ECC core moved to `rust/src/ecc_core.rs` and the std module runs on it (std suite and 1,339 vector rows unchanged)
  - agent: Dict and Utf8 walks are behind `text` so the base image grows 784 B only (Utf8Wire, count header, checks)
leftovers:
  - `_docs/02_tasks/todo/AZ-2756`, `AZ-2757` (unclaimed). Waves in `handoff53.md`
  - C++ core: a `when` whose source sits in a false `when` is matched (`21 00 05`, TrailingBytes); not a ticket yet (handoff53)
  - security Low L52-1 (a repair stays in the buffer when the field read then fails, documented) and L51-1
  - AZ-2757: nested-scheme stack probe with strings and dictionaries, the raw memo measurement, a `session` set for the embedded stage
  - owner: size limits for text/ecc/session; CS-D5; first `v*` / `go/v*` tags; F44
  - step 11: vcpkg checks NOT RUN on this host; ring and publish-gate needed re-runs under host load (see smoke52.md)
  - Jira: AZ-2754, AZ-2755 In Testing; epic AZ-2750 open
smoke: PASS (agent run 9/9 at 1d23c18, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop52/smoke52.md
assessment_artifact: _docs/loops/loop52/assessment52.md
step11: RESULT rust 92 s, scaffold 315 s, rust-embedded 6 s passed at 1d23c18; ring and publish-gate passed on the re-runs (96 s, 495 s)
review: `/code-review` high, 7 findings, 6 fixed, 1 done in the docs step, 0 High
security: PASS, 1 Low (L52-1), `_docs/05_security/nostd_review_loop52.md`
retro: _docs/06_metrics/retro_2026-10-20_loop52.md
loop_end_merge: main
