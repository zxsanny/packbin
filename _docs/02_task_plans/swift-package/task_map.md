# Task map — swift-package (AZ-2223, loop 26)

Specs in `_docs/02_tasks/todo/` named by their Jira keys (AZ-2513 to AZ-2524, created 2026-10-14 under epic AZ-2223). Shape mirrors the Go epic (AZ-2440 to AZ-2451). Total 47 points (Go: 45; the session grows 3 → 5 for the in-package ChaCha20).

| task file | points | deps | SW criteria owned | scenarios owned | secondary refs |
|---|---|---|---|---|---|
| AZ-2513_swift_core.md | 5 | none | SW-1, SW-2, SW-8, SW-14, SW-15 | S3, S4, S5 | SW-10 (manifest), SW-11 (no unsafe flags/C targets), SW-12 (scalars); S1, S2, S7, S8 |
| AZ-2514_swift_scheme_checks.md | 5 | AZ-2513 | — | — | SW-2, SW-3 (construction rows) |
| AZ-2515_swift_rounds.md | 5 | AZ-2514 | — | — | SW-2 (round kinds), SW-3, SW-12 (U11, empty array); S8 |
| AZ-2516_swift_collections.md | 5 | AZ-2515 | SW-12 | S8 | SW-2 (collections), SW-3, SW-15 (element types) |
| AZ-2517_swift_limits.md | 3 | AZ-2516 | SW-5 | S6 | — |
| AZ-2518_swift_session.md | 5 | AZ-2513 | SW-6, SW-11 | S12 | SW-14 (session one task at a time) |
| AZ-2519_swift_hostile_vectors.md | 3 | AZ-2517, AZ-2518 | SW-4 | S2 | — |
| AZ-2520_swift_parity_rows.md | 3 | AZ-2519 | SW-3 | — | — |
| AZ-2521_swift_ci_suite.md | 3 | AZ-2513 | SW-9 | — | SW-5 (60 s fuzz step), SW-8 (release-build speed), SW-11 (dependency check), SW-14 (thread sanitizer); S11 (Linux build) |
| AZ-2522_swift_ring.md | 3 | AZ-2518 | SW-7 | S1, S7 | — |
| AZ-2523_swift_release.md | 5 | AZ-2521, AZ-2522 | SW-10, SW-16 | S9, S10, S11 | — |
| AZ-2524_swift_readme.md | 2 | AZ-2520, AZ-2523 | SW-13 | — | — |

## Coverage check (primary owner, exactly once)

| criterion | owner | | scenario | owner |
|---|---|---|---|---|
| SW-1 | AZ-2513_swift_core | | S1 | AZ-2522_swift_ring |
| SW-2 | AZ-2513_swift_core | | S2 | AZ-2519_swift_hostile_vectors |
| SW-3 | AZ-2520_swift_parity_rows | | S3 | AZ-2513_swift_core |
| SW-4 | AZ-2519_swift_hostile_vectors | | S4 | AZ-2513_swift_core |
| SW-5 | AZ-2517_swift_limits | | S5 | AZ-2513_swift_core |
| SW-6 | AZ-2518_swift_session | | S6 | AZ-2517_swift_limits |
| SW-7 | AZ-2522_swift_ring | | S7 | AZ-2522_swift_ring |
| SW-8 | AZ-2513_swift_core | | S8 | AZ-2516_swift_collections |
| SW-9 | AZ-2521_swift_ci_suite | | S9 | AZ-2523_swift_release |
| SW-10 | AZ-2523_swift_release | | S10 | AZ-2523_swift_release |
| SW-11 | AZ-2518_swift_session | | S11 | AZ-2523_swift_release |
| SW-12 | AZ-2516_swift_collections | | S12 | AZ-2518_swift_session |
| SW-13 | AZ-2524_swift_readme | | | |
| SW-14 | AZ-2513_swift_core | | | |
| SW-15 | AZ-2513_swift_core | | | |
| SW-16 | AZ-2523_swift_release | | | |

Result: SW-1 to SW-16 each have exactly 1 primary owner (16 of 16); S1 to S12 each have exactly 1 primary owner (12 of 12); unowned 0, doubly owned 0.

## Write sets

- `swift/**`: tasks 01 to 08 and the README example test of 12, one worker at a time (dependency chain 01 → 02 → 03 → 04 → 05 → 07 → 08, with 06 after 01). `Package.swift`: 01 creates it, 06 adds `swift-crypto` and `Package.resolved`. `.gitignore` (Swift build-output lines): 01. `fixtures/hostile/fuzz/**` (new): 05.
- Shared CI files, disjoint: 09 (`run-suite.sh`, its tests, `test.yml` scaffold job, both compose files), 10 (ring driver, `ring-swift.sh`, `language-pair.sh`, `ring-toolchains.sh`, new Swift ring-wiring test, `test.yml` ring job), 07 (`fixtures/hostile/check-cases.sh`, `cases.test.sh`, `README.md`), 11 (publish scripts and tests, ADR-005, ADR index, `module-layout.md` Swift lines), 12 (`README.md`, `architecture.md`, `interaction-risks.md` Swift rows, `pack-session.md` Consumers line).
