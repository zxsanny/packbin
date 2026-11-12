# Autodev loop record - loop 112

loop: 112
branch: dev
plan_artifact: _docs/loops/loop112/plan112.md
tasks_shipped: [AZ-4206]
decisions:
  - owner (2026-11-12): one question with four options (refuse at build / the same with an exception for two `when`s that cannot both be taken / refuse at pack / keep as documented): "Refuse at build". A repeat must be the last thing a packet reads; the rule is `_docs/02_document/contracts/library/repeat-last.md`
  - agent (auto-applied, the owner can overrule them): Java and C++ also refuse a repeat inside a `repeat` or `times` round at build, as the other seven do today (contract case R9; flagged open, Low, in AZ-4214, AZ-4219, AZ-4210); the device pins follow the measured figure with a note, above 256 B of flash or 64 B of stack the owner decides (AZ-4218, AZ-4219); a new epic AZ-4209 for the ten tasks; probes under `scripts/probes/` (the spec allowed `fixtures/` or `scripts/`; `scripts/` reaches only the `scaffold` stage)
measurements:
  - `bash scripts/probes/repeat-followed-by-field/run.sh` (package sources of `9cfccda`): 85 lines, exit 0, 31 to 43 s, four runs byte-identical; 10 of 10 control lines read back
  - a field after a repeat (top level, nested row, under `when`, under `flags`): built, the same bytes, and refused on unpack in 10 of 10 forms (nine packages, Rust twice); a repeat in a list or dict element row: 7 packages the same, Rust (both APIs) and bound C++ lists refuse the row itself
  - two repeats in a row (`repeat(v), repeat(w)`, added during the loop): `010506`, read back as other values with no error in 10 of 10 forms
  - `rule-count/run.sh` (TypeScript suite 3,642 of 3,642 in a temporary copy): 77,266 schemes built, 11 by the ring drivers; the rule refuses 4 test schemes in 3 files and 0 shared fixtures, golden vectors or ring schemes
  - the still-building cases K1 to K5 of the contract, run in TypeScript: `01090506`, `01010506`, `0103090506`, `0102050609`, `0103090506`
  - step 11 `scripts/loop-tests.sh` at `5bac143`, stamps seeded with the last total run (`bb99503`): `scaffold` PASS (362 s), 14 stages skipped as unchanged, 0 failed; NOT RUN (unchanged since loop 98): vcpkg supports and consumer checks
  - smoke: 8/8 (`smoke112.md`)
review: "PASS_WITH_WARNINGS, 5 Medium and 15 Low (`_docs/03_implementation/reviews/batch_01_loop112_review.md`): 18 fixed before the batch commit, 2 kept with reasons; two read-only reviewers and the parent; the four special claims of the table confirmed in the package sources"
feature_assessment: COMPLETE, round 1 (`assessment112.md`): 13 covered, 1 out of scope
security: not in plan (trivial: probes and documents only, no package source, no CI, compose or deploy file, no dependency)
retro: none (due by loop 113)
leftovers:
  # converted on 2026-11-12 at the first P0 under the work-queue protocol (loop 113); this list stands for the free-text leftovers of the records of loops 98 to 112
  - _docs/02_tasks/todo/AZ-4210_repeat_last_hostile_cases_and_readme.md to AZ-4219 (epic AZ-4209; claimed by loop 113)
  - _docs/02_tasks/backlog/element-row-sibling-probe.md
  - _docs/02_tasks/backlog/loop-tests-stamp-on-dirty-docs.md
  - _docs/02_tasks/backlog/csharp-dotnet-test-hang-without-console-logger.md
  - _docs/02_tasks/backlog/s390x-percentage-packets-vs-m3.md
  - _docs/02_tasks/backlog/embedded-arm-dns-cause.md
  - _docs/02_tasks/backlog/dart-readme-install-lines-after-first-publish.md
  - _docs/OPERATOR_TODO.md N1 (first `dart pub publish`), N2 (vcpkg tool), N3 (Archangel schemes), N4 (autodev skill sentence)
  - _docs/OPERATOR_TODO.md D1 (Java and C++ refuse a repeat inside a round), D2 (U24), D3 (vcpkg `supports`), D4 (Dart API choices of loop 99), D5 (public-key pairing step), D6 (released tickets to Done)
notes:
  - not work, kept for the record: the send branch of the AZ-4196 key upload has not run for real (`publish-key` is the manual fallback); keyserver.ubuntu.com did not answer in loop 105; no physical board was ever used (QEMU `mps2-an505` only); the root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants` are gone (checked 2026-11-12)
  - Jira at close: AZ-4206 In Testing; AZ-4209 (epic) and AZ-4210 to AZ-4219 To Do; AZ-4205, AZ-4198, AZ-4199 In Testing; the next tag carries AZ-4205
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed; checks in smoke112.md)
smoke_artifact: _docs/loops/loop112/smoke112.md
assessment_artifact: _docs/loops/loop112/assessment112.md
loop_end_merge: main
