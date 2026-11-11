# Autodev loop record - loop 108

loop: 108
branch: dev
plan_artifact: _docs/loops/loop108/plan108.md
tasks_shipped: []
decisions:
  - owner (2026-11-11): chose "Retro of loops 105-107" for the empty hopper (other options offered: runner DNS cause, Dart first-publish prep, own feature)
  - agent: documents only; no ticket (as in loop 104); one clause added to the Python 3.13 gotcha (the `phases` groups trip on it too); AZ-4196 moved to In Testing after its dev run was read green
measurements:
  - retro: `_docs/06_metrics/retro_2026-11-11_loop108.md` (2 tasks, 8 files outside `_docs/`, +162 -4 lines, 0 review findings, 0 product defects, 4 CI or script defects found by running); `structure_2026-11-11_loop108.md` (9 components, 0 edges, 0 cycles)
  - lessons: 3 appended to `_docs/LESSONS.md` (15 entries, each with a Source file that exists; the three oldest dropped)
  - CI of the loop 107 push: dev run 43091735508 success (20 of 20); main run 43092181967 still running at close
  - smoke: 7/7 (`smoke108.md`): retro and snapshot, 15 lessons with sources, gotcha clause, documents-only diff, no tag, dev run green
review: "none (documents only)"
retro: _docs/06_metrics/retro_2026-11-11_loop108.md (next retro due by loop 113)
leftovers:
  - the real keyserver upload path (key missing on keys.openpgp.org) runs for real at the first tag run after the key drops; read its step then; `publish-key` is the manual fallback
  - the embedded-arm host-network build goes around the runner's bridge DNS without finding the cause (loop 106; retro action 3)
  - owner (unchanged): first `dart pub publish`, then automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - the autodev rule file `worktree-isolation.md` is outside this repository ("the push is the CI trigger" is wrong for a documents-only push); a `Start:` commit must cite a ticket id that exists
  - from loops 98 to 107 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built; keyserver.ubuntu.com did not answer in loop 105
  - Jira: AZ-4196, AZ-4191, AZ-4168, AZ-4169, AZ-4153 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 7/7 steps passed at 11364e4; checks in smoke108.md)
smoke_artifact: _docs/loops/loop108/smoke108.md
loop_end_merge: main
