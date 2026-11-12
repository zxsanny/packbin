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
  - epic AZ-4209 (`todo/`, unclaimed, 29 points): AZ-4210 first (shared hostile cases and README), then AZ-4211 to AZ-4219 (one per package) in waves of four workers (TypeScript, C#, Python, Java; Go, Swift, Dart, Rust; C++ with its embedded rows); `_docs/02_task_plans/repeat-must-be-last/feature-description.md` has the order
  - owner, before AZ-4214 and AZ-4219 start: say so if Java and C++ should keep building a repeat inside a round (the agent default refuses it)
  - not measured: the test schemes the rule refuses in the eight packages other than TypeScript (each task counts its own); Archangel's schemes (another repository; check before the upgrade)
  - process: `scripts/loop-tests.sh` writes a stage's stamp only on a tree that is clean apart from the state file, so the default plan re-ran 9 stages that had passed; step 11 seeded `LOOP_TESTS_STAMPS` with `bb99503` (batch report, discovery 7). `scaffold` takes 362 to 386 s for a change under `scripts/` that no scaffold test reads
  - from loop 109 (unchanged): `dotnet test csharp` hang without a console logger; the embedded-arm DNS cause (not reproduced); the sibling probe of the AZ-4199 element row in Java, Go, Swift, Rust, Python and C++
  - owner (unchanged): first `dart pub publish`, then automated publishing; the two README lines that say Dart is installed from the repository
  - Jira: AZ-4206 In Testing; AZ-4209 (epic) and AZ-4210 to AZ-4219 To Do; AZ-4205, AZ-4198, AZ-4199 In Testing (unchanged); the next tag carries AZ-4205
  - from loops 98 to 110 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built; keyserver.ubuntu.com did not answer in loop 105; the autodev rule file `worktree-isolation.md` is outside this repository
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed; checks in smoke112.md)
smoke_artifact: _docs/loops/loop112/smoke112.md
assessment_artifact: _docs/loops/loop112/assessment112.md
loop_end_merge: main
