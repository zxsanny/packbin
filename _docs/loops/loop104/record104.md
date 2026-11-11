# Autodev loop record - loop 104

loop: 104
branch: dev
plan_artifact: _docs/loops/loop104/plan104.md
tasks_shipped: []
decisions:
  - owner (2026-11-11): "Yes, retro", the retrospective of loops 101 to 103 (due by loop 104)
  - agent: documents only; one rule update in `_docs/04_deploy/ci_cd_pipeline.md` (a documents-only push starts no CI run; `gh` is the status tool); three orphan Source lines of loop 99 removed from `LESSONS.md`
measurements:
  - retro: `_docs/06_metrics/retro_2026-11-11_loop104.md` (2 tasks, 7 points, 2 batches, 0 review findings, 2 product defects found by measurement and fixed, 0 reruns of step 11, 4 CI runs green); `structure_2026-11-11_loop104.md` (9 components, 0 edges, 0 cycles)
  - lessons: 3 appended to `_docs/LESSONS.md` (15 entries, each with a Source file that exists)
  - smoke: 6/6 (retro and snapshot, 15 lessons with sources, the polling rule, documents-only diff, no tag)
review: "none (documents only)"
retro: _docs/06_metrics/retro_2026-11-11_loop104.md (next retro due by loop 109)
leftovers:
  - owner (before the first tag that contains `dart/`; unchanged): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - the published packages (npm 0.4.0, NuGet and Maven Central 0.4.0) do not have the loop 101 and 103 changes; the next tag carries them
  - the autodev rule file `worktree-isolation.md` § Loop close on `dev` still says the `dev` push "is the CI trigger"; it is outside this repository (the project config `ci_cd_pipeline.md` now carries the exception)
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool); a physical board; OIDC token lifetime and pub.dev's answer to a re-publish (unproven until the first tag)
  - from loops 98 to 103 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built
  - Jira: no ticket this loop (no task); AZ-4169, AZ-4168, AZ-4153 and AZ-4134 to AZ-4149 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 6/6 steps passed at 59da870; checks in smoke104.md)
smoke_artifact: _docs/loops/loop104/smoke104.md
loop_end_merge: main
