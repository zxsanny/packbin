# Autodev loop record — loop 70

loop: 70
branch: dev
plan_artifact: _docs/loops/loop70/plan70.md
tasks_shipped: [AZ-3231_rust_m33f_embedded_row]
decisions:
  - owner (2026-10-25, AskQuestion at loop start, recommended option): the loop is the Rust Cortex-M33F row (moved from loop 69)
  - agent: ceilings 64 KB / 8 KB from the C++ row (`m33f_*`, owner 2026-10-25) and pins equal to the figures measured with Rust 1.98.1 (the CI toolchain), like `cpp-m33f`; the M4F limits keep their measured-plus-5% rule
  - agent: Jira AZ-3231 created under AZ-2750 (3 points), In Progress then In Testing, read back
  - agent: the seeded-defect mutants stay on the M4F row (the link checks read symbol names, not the architecture)
  - agent: found at step 11 that Rust 1.79 (Mac default) gives less flash but more stack than 1.98.1; `run.sh libs` now selects `PACKBIN_EMBEDDED_RUST` (default 1.98) on every host
leftovers:
  - owner: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row (the M33F row needs the M4F logs for the route compare, so dropping it needs that compare reduced)
  - owner: frame mode in the other seven packages and the order (C#, Java, Swift first); PB-02 vector tests there; a replay window per key slot (F69-2); whether `frame` is on with `std`; hardening of the `hkdf.rs` temporaries
  - open: CI figures of the `rust-m33f` row (read after the push)
  - Jira: AZ-3231 In Testing at close (read back); AZ-3192 umbrella and epic AZ-3199 as in the loop 69 record
smoke: PASS (agent run 5/5, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop70/smoke70.md
assessment_artifact: _docs/loops/loop70/assessment70.md
step11: `scripts/loop-tests.sh` at `7e4fe18`: rust, scaffold, ring, publish-gate PASS, rust-embedded FAIL (toolchain); at `cd44868`: rust, rust-embedded, ring PASS (3 passed, 11 skipped as unchanged, 0 failed); `vcpkg` checks NOT RUN (no tool on this host)
review: feature-assess COMPLETE (9 covered, 0 gaps); no per-batch code review (owner preference); security step not in plan (no auth, secrets or untrusted input touched)
loop_end_merge: main
