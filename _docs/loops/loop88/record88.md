# Autodev loop record - loop 88

loop: 88
branch: dev
plan_artifact: none (short loop on the launcher: docs only, no code, no plan, no feature-assess)
tasks_shipped: [AZ-3435 release notes 0.4.0]
decisions:
  - owner (2026-10-30, hopper empty): asked how important the handoff's owner items are and whether the epic AZ-2750 is implemented; said "I would say 0.4.0 in release notes", then "Yes, notes" to making loop 88 the 0.4.0 release notes
  - agent: Jira AZ-3435 created at intake (Task, Medium); In Testing after the work (read back from the transition result)
  - agent: the notes are a repository document, `_docs/04_deploy/release_notes_0.4.0.md`, whose body between the two rules is the GitHub release body; no tag, release or upload (owner-run)
measurements:
  - sources read on HEAD c79c40b+1: README diff against `v0.3.0`, ADR-006 to ADR-009, `fixtures/text/tables.report.md`, the contract headers (compact-text 1.0.0, message-ecc 1.0.1, pack-session 3.0.0), loop records 35 to 77, `AZ-2713`; `fixtures/golden.hex` is identical at `v0.3.0` and HEAD
  - 330 commits and 1,724 files between `v0.3.0` and HEAD; the CI of the loop 87 close push (`dev` and `main`) finished green
review: "parent re-read of every figure against its source; two corrections made (compact text percentages, message-ecc contract version)"
retro: none this loop; next retro due after loop 89
leftovers:
  - owner: tag `v0.4.0` (and `go/v0.4.0` through the publish run); decide CS-D5 before it (the compact text tables are frozen with the format); F44 (no tag ruleset on `v*`, the rulesets API returned none on 2026-10-30)
  - owner: close the epic AZ-2750 (all eight slices and AZ-3231 shipped; AZ-2756's `session` feature was later removed by ADR-009)
  - owner (unchanged): U24 in the C++ package; whether to drop the M4F row; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step; multi-part MAC rows in the ring
  - stale wording corrected: the first `v*` and `go/v*` tags exist (v0.3.0 and go/v0.3.0, 2026-10-16); only F44 and later tags are open
  - Jira: AZ-3435 In Testing
smoke: PASS (owner, 2026-10-30: 6 reading checks; docs only, no local deploy)
smoke_artifact: _docs/loops/loop88/smoke88.md
loop_end_merge: main
