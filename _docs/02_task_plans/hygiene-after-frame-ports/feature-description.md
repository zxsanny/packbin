# Feature description — hygiene after the frame ports (loop 76)

Seven small defects left by loops 71 to 75, found and measured in `problem.md` of this folder (read it first; acceptance criteria in `acceptance_criteria.md`, figures in `input_data/expected_results/results_report.md`). Owner choice of 2026-10-27: items 1 to 5 and 7, item 6 investigate-first (the probe is wrong, not the packages), AVR check out. No change to frame bytes, fixtures, the contract or an embedded pin. Total estimate 11 points over five disjoint tasks, so it hands off to `/decompose --feature`.

Epic: AZ-2645 (the one earlier hygiene tasks AZ-3163, AZ-3164 and AZ-3256 used).

## Tasks

| Slug | Items | Place | Points |
|------|-------|-------|--------|
| probe_fixes | 2, 6 | `fixtures/hostile/fuzz/csharp/` (csproj, `EdgesText.cs`), `fixtures/hostile/fuzz/java/packbin/ProbeEdgesText.java` | 2 |
| timing_selftest_no_pipe | 1 | `.github/workflows/publish-timing.selftest.sh` | 2 |
| rust_feature_set_tests | 3 | `rust/src/session_core/{sha256,hkdf}.rs` test modules, the 22 std-only files of `rust/tests/*.rs` | 3 |
| docs_swift_docc_vcpkg_reason | 4, 5 | `swift/Sources/Packbin/Packbin.docc/Packbin.md`, ADR-003 line 48, `05_cpp_package/description.md` line 136 | 2 |
| session_names | 7 | `csharp/tests/` two files, `fixtures/hostile/fuzz/{python,typescript}/fuzz_ecc_session.*`, their readers | 2 |

Write sets are disjoint; one wave of five workers; the parent applies `_docs/AGENT_GOTCHAS.md`, the loop record and the Jira moves.

## Scenarios

See `scenarios.md` (12 rows: 11 confirmed, 1 out-of-scope).

## Fit decisions

None (no collision with today's behavior).
