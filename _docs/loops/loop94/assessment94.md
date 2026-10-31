# Feature assessment - loop 94

FEATURE ASSESSMENT loop 94 round 1: COMPLETE - 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

Intent: owner asked to drop the M4F rows (both), place: arm test stage plus docs. Baseline: `_docs/02_task_plans/drop-m4f-rows/` (`problem.md`, `acceptance_criteria.md`, `scenarios.md`), spec `AZ-3479`.

| id | status | AC | test | code path |
|----|--------|----|------|-----------|
| S1 first full run | covered | AC-1, AC-5 | `loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold` | `cpp/embedded/run.sh` table, `rust/embedded/run.sh` |
| S2 rust-m33f alone | covered | AC-3 | scratch copy run (batch report) | `target.sh` `rust_row` without `rust_same_as` |
| S3 route bytes differ on one target | covered | AC-3 | probe `pb_rs_route_unpack` compares with the sample; `FAILURES` and `GOLDEN_OK` checks in `rust_row` | `probe/src/lib.rs`, `main.cpp` |
| S4 seeded defect | covered | AC-4 | scratch run with the clean lib fails the row | `target_rust_mutants` |
| S5 core grows, no M4F gate | covered | AC-7 | words: AGENT_GOTCHAS line states the M33F pins are the only bar | `m33f_*` pins in `lib.sh`, `limits-m33f.txt` |
| S6 reader looks for M4F figures | covered | AC-7 | `git grep` (batch report); docs in step 13 | README, GOTCHAS, rust README |
| S7 host NO_TEXT / NO_ECC builds | covered | AC-5 | `make -C cpp no-text-test no-ecc-test` untouched; Uno row PASS | `cpp/Makefile`, `target_avr_uno` |
| S8 CI job | covered (static) | AC-7, AC-8 | YAML parses; step names and `rustup target add` edited; the CI run itself comes with the close push | `.github/workflows/test.yml` |

No `Discovered during implementation` row is unclear (batch report). `scenarios.md` unchanged.
