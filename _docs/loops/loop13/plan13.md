# Autodev Loop Plan — Loop 13

loop: 13
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree — owner decision 2026-10-05, as loops 11 and 12). Scope (owner choice, group A): the next High-severity bug fixes in plan order (`_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md` tasks 15–19, 21, 22; epic AZ-2069): AZ-2084 (TypeScript), AZ-2085 and AZ-2086 (Rust), AZ-2087 and AZ-2088 (C#), AZ-2090 and AZ-2091 (TypeScript). 19 points. Three package streams, each serialized by its own dependencies.

No Critical `open` concern in any of the seven specs. Open Medium concerns carried, not decided here: TypeScript `repeat`/`times` pack only direct children per item (AZ-2090 and AZ-2091, unowned), Rust composite list/dict elements (C18), Rust `repeat`/`times` inside a map group element (AZ-2086).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | seven specs of 2–3 points exist |
| implement | 10 | Implement | yes | AZ-2084, AZ-2085, AZ-2086, AZ-2087, AZ-2088, AZ-2090, AZ-2091 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs unchanged; packages are brought to existing ACs; construct vectors come from AZ-2070 |
| update-docs | 13 | Update Docs | yes | Rust typed `times` API, C# and TypeScript pack errors, new construction errors touch README and package docs; no other loop in flight |
| security | 14 | Security Audit | yes | changed from `no` at batch 2 (new evidence): C# aligned unpack pads one `null` per optional name per round (337 MB heap for a 1 MB packet, was 57 MB) and Rust typed/map `times` keeps one row per round (312 MB RSS for 1 MB, was 37 MB; 1.42 GB worst case); both are untrusted-input resource use. Batch 3 adds the same in TypeScript |
| performance | 15 | Performance Test | no | no perf NFR; AC-10 round-trip budget runs in Run Tests |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 19 points across 7 tasks; loop 12 had none |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Task groups (disjoint write sets)
- typescript: AZ-2084 → AZ-2090 → AZ-2091 (same package, serialize) — `typescript/**`, `.github/workflows/drivers/handoff.ts`
- rust: AZ-2085 → AZ-2086 (same package, serialize) — `rust/**`, `.github/workflows/drivers/handoff-rust/**`
- csharp: AZ-2087 → AZ-2088 (same package, serialize) — `csharp/**`, `.github/workflows/drivers/csharp/**`
- parent: `.github/workflows/language-pair.sh`, README, `fixtures/hostile/**`, `_docs/`

## Batches
1. AZ-2084 (TypeScript), AZ-2085 (Rust), AZ-2087 (C#) — three workers in parallel, one review, one commit
2. AZ-2090 (TypeScript), AZ-2086 (Rust), AZ-2088 (C#) — same shape
3. AZ-2091 (TypeScript)

## Implementation

Divergence recorded at the batch 1 commit: the first C# review FAILed AZ-2087 (AC-4's pack leg is false: C# pack dropped values under `when` / `flags` / groups in a round). Owner decision 2026-10-05, option B: fix it in AZ-2087, which pulls the C# part of AZ-2134 (owner decision U2, aligned round values) into this loop. AZ-2087 is now 5 points, AZ-2134 keeps TypeScript and Python (3 points). A second owner decision (2026-10-05, batch 2) pulls the TypeScript twin, pack by round index plus aligned unpack, into AZ-2091 (now 6 points); AZ-2134 keeps Python only (2 points). The loop total stays 7 tasks, now 25 points.

### Files that change
- typescript (AZ-2084): `src/kinds.ts`, `src/pack-fields.ts` (edit); `tests/int-range.test.ts` (new)
- rust (AZ-2085): `src/field/integrity.rs`, `src/integrity_tests.rs`, `tests/bound_names_tests.rs` (new); `src/field/{map_scheme,mod,shape}.rs`, `src/scheme/mod.rs`, `src/value.rs`, `src/walk/{pack,unpack}.rs`, `src/lib.rs`, `src/{element,round}_tests.rs`, `tests/field_id_tests.rs` (edit)
- csharp (AZ-2087): `Packbin.cs` (`SchemeOrder` scope resolution, `Walk` split), `Walker.cs`, `Walker.Counted.cs` (edit); `Walker.Rounds.cs` (new: round slicing and alignment); tests `ReferenceScopeTests.cs`, `RoundValueTests.cs` (new), `HostileVectorTests.cs`, `HostileUnpackTests.cs`, `HostileUnpackTests.Counts.cs`, `ZeroWidthElementTests.cs` (edit)
- batch 2 typescript (AZ-2090): `src/ref-scope.ts`, `tests/reference-scope.test.ts` (new); `src/{fields,index,kinds,pack-fields,walker}.ts`, `tests/{flag-scope,hostile,value-fidelity}.test.ts`, `tests/support/hostile-cases.ts` (edit)
- batch 2 rust (AZ-2086): `src/scheme/times.rs`, `src/walk/times.rs`, `src/times_tests.rs`, `src/times_stale_tests.rs`, `tests/times_tests.rs`, `tests/times_names_tests.rs`, `tests/times_route_tests.rs` (new); `src/scheme/mod.rs`, `src/walk/{mod,pack,unpack}.rs`, `src/field/mod.rs`, `src/value.rs`, `src/lib.rs`, `src/{flag_bits,round}_tests.rs` (edit)
- batch 2 csharp (AZ-2088): `Field.cs`, `Packbin.cs`, `Walker.cs`, `Walker.Counted.cs`, `Walker.Presence.cs`, `Walker.Rounds.cs` (edit); tests `LoudPackTests.cs`, `SchemeOwnershipTests.cs`, `FloatWhenTests.cs` (new), `FieldIdBindingTests.cs` (edit)
- batch 3 typescript (AZ-2091): `src/rounds.ts`, `src/member-names.ts`, `tests/nested-group.test.ts`, `tests/round-values.test.ts`, `tests/round-roundtrip.test.ts` (new); `src/{fields,index,pack-fields,walker}.ts`, `tests/{value-fidelity,reference-scope}.test.ts` (edit)
- shared (parent): README upgrade notes and component docs at step 13; `_docs/02_tasks/` spec and dependency-table updates

### Order of work
1. Batch 1: TypeScript, Rust, C# workers in parallel; three fresh reviewers; C# FAIL, owner decision, C# round 2 and 3, C# re-review (PASS_WITH_WARNINGS)
2. Batch 2: AZ-2090, AZ-2086, AZ-2088 (reviews: TypeScript PASS_WITH_WARNINGS, C# PASS_WITH_WARNINGS, Rust FAIL then fixed by owner decision A and re-reviewed PASS_WITH_WARNINGS); batch 3: AZ-2091 including the TypeScript round slicing (review PASS_WITH_WARNINGS; one test-only fix round)

### Proof
- `int-range.test.ts`, `integrity_tests.rs` / `bound_names_tests.rs`, `ReferenceScopeTests.cs` / `RoundValueTests.cs` (each red before, green after); hostile construct vectors `when_names_later_field`, `count_names_later_field`, `when_names_outer_field_in_repeat` in C#
- Docker CI suites for all six languages, strict `tsc`, `language-pair.sh` rings

### Risks
- Rust typed `times` is a public API change and its unpack costs about 8x memory (README note); C# `pack` now throws where it silently dropped data (AZ-2088); TypeScript pack refuses out-of-range and unsafe 64-bit numbers (README note); Rust refuses `when` on non-integer sources and composite list/dict elements (a `when` on a utf8 source with a same-type `eq` worked before); C# unpacked rows change shape for values under `when` / `flags` / groups inside a round (aligned lists with `null`), and unpack memory grows to about packet bytes × names per round

## Assessment rounds

Optional. Appended by `protocols/feature-reentry.md` when `feature-assess` returns `EXTEND` / `CLARIFY`.
