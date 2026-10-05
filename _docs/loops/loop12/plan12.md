# Autodev Loop Plan — Loop 12

loop: 12
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree, same as loop 11). Scope: the `bool` rule and 8-bit flag limit in every package that still lacks it — bug-fix plan tasks 10, 11, 13, 14 and 20 (epic AZ-2069): AZ-2079 (C#), AZ-2080 (TypeScript), AZ-2082 (Rust), AZ-2083 (Python), AZ-2089 (Java). C++ already conforms (AZ-2081, loop 10).

Placement rule for all five, from the C++ precedent (`cpp/include/packbin/order.hpp` `check_shape`): a `bool` or an empty group is accepted only as a **direct** child of `flags` or of a flag bit. Anywhere else, including inside a group under flags, it is a construction error. This settles the Low `open` concern in AZ-2079, AZ-2080 and AZ-2083.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | five specs of 1–2 points exist |
| implement | 10 | Implement | yes | AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs unchanged; packages are brought to existing AC-3 |
| update-docs | 13 | Update Docs | yes | construction errors and the `bool false` wire change touch README and package docs; no other loop in flight |
| security | 14 | Security Audit | no | construction-time scheme checks, no untrusted-input path changed; last report 2026-10-05 |
| performance | 15 | Performance Test | no | no perf NFR; AC-10 round-trip budget runs in Run Tests |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | each task ≤ 2 points, no incident, last retro loop 11 |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Task groups (disjoint write sets)
- csharp: AZ-2079 — `csharp/**`, `.github/workflows/drivers/csharp/**`
- typescript: AZ-2080 — `typescript/**`, `.github/workflows/drivers/handoff.ts`
- rust: AZ-2082 — `rust/**`, `.github/workflows/drivers/handoff-rust/**`
- java: AZ-2089 — `java/**`, `.github/workflows/drivers/Handoff.java`
- python: AZ-2083 — `python/**`, `.github/workflows/drivers/handoff.py`
- parent: `.github/workflows/language-pair.sh`, `.github/workflows/drivers/handoff.cpp` (new `boolflag` handoff ring), README, `_docs/`

Cross-language vector `boolflag`: scheme type 1 = `flags(0, [bool(0, on)])`, row `{on: false}` packs `0100` in every package; unpack of `0100` is ok and `on` is not `true`.

## Implementation

Divergence recorded at the batch commit: review fix rounds widened the C#, Java and Rust changes beyond the five specs (owner decisions 2026-10-05, batch 1 report); three follow-ups filed (AZ-2126, AZ-2127, AZ-2128); a `booltrue` (`0101`) leg joined the cross-language ring.

### Files that change
- csharp: `FlagGroup.cs`, `Packbin.cs`, `Walker.cs` (edit); `Walker.Presence.cs` (new); tests `BoolFlagRuleTests.cs`, `FlagGroupValueTests.cs` (new), `HostileVectorTests.cs`, `HostileUnpackTests.cs` (edit)
- typescript: `src/fields.ts`, `flag-scope.ts`, `index.ts`, `kinds.ts`, `walker.ts` (edit); tests `bool-flag.test.ts` (new), `borrowed-count.test.ts`, `hostile.test.ts`, `support/hostile-cases.ts` (edit)
- python: `src/packbin/_nodes.py` (edit); tests `test_bool_placement.py` (new), `test_hostile_vectors.py` (edit)
- rust: `field/{mod,order}.rs`, `scheme/mod.rs`, `walk/{pack,unpack,element}.rs`, `lib.rs`, `hostile_tests.rs`, `element_tests.rs` (edit); `field/{shape,map_scheme}.rs`, `flag_bits_tests.rs`, `flag_presence_tests.rs` (new)
- java: `Containers.java`, `Field.java`, `SchemeOrder.java`, `VarFields.java`, `Walker.java` (edit); `Rounds.java` (new); tests `BoolPlacementTest`, `ReferenceScopeTest`, `RepeatRoundTest` (new), `FlagStateTest`, `HostileUnpackTest`, `HostileVectorTest`, `PackbinTest`, `ZeroWidthElementTest` (edit)
- shared: `.github/workflows/language-pair.sh`, all six `drivers/` handoffs, `README.md`, `fixtures/hostile/README.md`

### Order of work
1. Batch 1: C#, TypeScript, Rust, Java workers in parallel; Python by the parent
2. Fresh-reviewer pass per package group; owner decisions; fix round 2 (all five packages); re-review of C#, Java, Rust; Java fix round 3

### Proof
- Each package's new bool/flag tests (red before, green after), hostile construct vectors, `language-pair.sh` `boolflag` + `booltrue` rings
- Docker CI suites for all six languages PASS

### Risks
- Wire change for `bool false` in C#, TypeScript and Rust map schemes (README upgrade note); Java unpack of `repeat`/`times` now returns per-round aligned lists
