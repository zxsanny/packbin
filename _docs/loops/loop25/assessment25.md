# Feature assessment — loop 25

loop: 25
feature: loop 25 owner batch (AZ-2472 to AZ-2479; decisions D1 to D7, U24 B, U25 A, U26 A, Low-1 A, D8)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-14
**Implement pass**: batch 01 (`b5c804e`) and batch 02 (`58d912c`, `df756c8`); reports `_docs/03_implementation/batch_01_loop25_report.md` and `batch_02_loop25_report.md`.
**Verdict**: CLARIFY — 16 covered / 1 out-of-scope / 1 gap-clear / 1 gap-unclear. No re-entry round (owner rule: do not chain assessment rounds); the gap-unclear row goes to the loop 26 handoff and the gap-clear row is documentation done at step 13.

Input notes:
- Intent baseline: there is no feature folder under `_docs/02_task_plans/` for this loop. The baseline is `_docs/loops/loop25/handoff25.md` (the decision table D1 to D7, F44, the short wave, D8), the owner's batch answer of 2026-10-14 ("accept all recommended"), and the acceptance criteria of the eight specs. `scenarios.md` is absent (no feature plan); noted as a harness gap, not a failure.
- Discoveries: both batch reports' `## Discovered during implementation` tables (13 rows) and the D1/D7 probe tables.
- Probes: TypeScript was run for real (`node --experimental-strip-types` on `typescript/src`) by the five probe workers for every D1 and D7 row; the C# AC-1 hex `010701` of AZ-2473 is the worker's own computation (its expected-hex constants elsewhere come from TypeScript and are unchanged).

### Coverage matrix

| id | scenario | status | evidence (AC + test + code) | source |
|----|----------|--------|-----------------------------|--------|
| S1 | A C++ scheme with a field id, `when` anchor or count id above 32,767 is refused when it is validated | covered | AZ-2472 AC-1 to AC-3; `cpp/tests/core/builder_id_range_host_tests.cpp` (each case wraps to a valid id, with a control that builds; mutation-checked: 21 failures with both hunks reverted); `cpp/include/packbin/table.hpp` `leaf`, `fields_counted.hpp` `counted_leaf` | intake U25 A |
| S2 | A count id of -1 still builds and fails every pack and unpack with `BadValue` | covered | AC-4; same test file (AC-4 case); `counted_leaf` keeps -1 | intake U25 A |
| S3 | The C++ library still fits the Cortex-M4F budget | covered | AC-5; arm stage on the final `cpp/include` and `cpp/src`: flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B (margin 56 B), unchanged | intake U25 A |
| S4 | The boundary: id 32,767 builds and 32,768 is refused | covered | AC-1; pair pinned on the node through `check_shape` for bits, packed, sized, times, a field id and a `when` anchor (a whole scheme with id 32,767 needs 32,768 fields) | batch 01 rework |
| S5 | A C# dictionary row packs a nested-row group from the nested dictionary | covered | AZ-2473 AC-1; `csharp/tests/DictNestedRowGroupTests.cs`; `csharp/Walker.cs` `PackGroup`, `Walker.Presence.cs` `ScopeOf` | intake U26 A |
| S6 | A flat dictionary row (the group's names at the outer level) is refused, naming the inner member or the group | covered | AC-2; same test file (3 cases); `Walker.cs` | intake U26 A |
| S7 | A dictionary row unpacked in C# comes back with the group nested, and repacks to the same bytes | covered | AC-3; `DictNestedRowGroupTests.cs`; `Walker.cs` `UnpackGroup`; README records the breaking change | batch 01 discovery 5 |
| S8 | Nested-row groups inside `repeat`/`times` rounds, list and dict elements, flags and typed rows keep their bytes | covered | AC-4; `RoundValueTests`, `LayoutTests`, `NoValueCountNestedTests`, `TypedParityTests`, `DictionaryElementTypedRowTests` (expected hex unchanged, only the dictionary inputs wrapped); `Walker.Collections.cs`, `Walker.Elements.cs` | batch 01 discovery 6 |
| S9 | Python raises `ValueError` with TypeScript's text for a value given to a member whose count no field wrote (bits, packed, sized, times) | covered | AZ-2474 AC-1 to AC-4; `python/tests/test_az2474_value_error_text.py` (10 tests); `python/src/packbin/_pack.py`, `_pack_rounds.py` `_borrowed` | intake Low-1 A |
| S10 | Go's peak memory for the F10 packet and the wide round is measured | covered | AZ-2475 AC-1, AC-2; `go/mem_test.go` (tag `packbin_memtest`): 625 MB and 94 MB; README memory bullet | intake D8 |
| S11 | Each of the six non-Go suites fails on a tree without its manifest and writes one FAIL row | covered | AZ-2477 AC-1; `.github/workflows/run-suite.test.sh` (mutation-checked against the old script: every bare tree passed before); `run-suite.sh` `missing_manifest` | intake D6 A |
| S12 | The present-manifest path of the six is unchanged | covered | AC-2; fake tools for csharp, rust, cpp, java in `run-suite.test.sh`; TypeScript and Python (venv fakes) by the existing cases; the real compose run of all seven is step 11 | intake D6 A |
| S13 | A tree that lost a language still publishes nothing for it (AC-15) | covered | AC-3; `publish-gate.sh` prints `absent <lang>` by itself and no publish script calls `run-suite.sh`; `publish-gate.test.sh` runs at step 11 | intake D6 A |
| S14 | Python, Rust, C#, Java and C++ pack, unpack and repack the split flag bit inside a false `when` as TypeScript | covered | AZ-2478 AC-1 to AC-4; `test_loop25_probe_d1_d7.py`, `loop25_probe_d1_d7_tests.rs`, `Loop25ProbeD1D7Tests.cs`, `Loop25ProbeD1D7Test.java`, `loop25_probe_d1_d7_host_tests.cpp`; no walker change | intake D7 A |
| S15 | The empty anchored group in the five other packages is probed against TypeScript and the result is recorded | covered | AZ-2476 AC-1 to AC-3; the same five files; tables in `batch_02_loop25_report.md`; differences (Python refuses construction; Rust numbers the id slot and builds a `when` on the mark; Java `Boolean.FALSE` packs the set bit and unpack gives `{mark:{}}`; C++ builds a `when` on the mark) kept under decision A | intake D1 A |
| S16 | The README says C++'s unbound member is the "not carried" spelling and records the decided open rows | covered | AZ-2479 AC-1 to AC-3; `README.md` bullet "Decided in loop 25" | intake U24 B |
| S17 | The first `go/vX.Y.Z` tag and the F44 tag ruleset | out-of-scope | handoff25: "The first `go/vX.Y.Z` tag: only with the owner's explicit go ... and the F44 ruleset applied"; F44 is applied by the owner in the repository settings, the agent cannot | handoff25 |
| G2 | AZ-2475 AC-3: the Go row (625 MB, 94 MB) is not yet in the loop 22 memory table | gap-clear | quote: AZ-2475 AC-3 "Given the AC-1 and AC-2 figures When the loop 22 retro table is read Then it has a Go row with both numbers" → the table lives in `_docs/02_document/tests/blackbox-tests-15-loop22-parity-and-memory-bound.md` (and `resource-limit-tests.md`); documentation only, done at step 13 | batch 01 |
| G1 | The C++ range-check error names the wrapped id, not the id the caller wrote | gap-unclear | see G1 below | batch 01 discovery 3 |

### Gaps that need a decision (gap-unclear)

#### G1: Which id the C++ range-check error names

**What is not decided**
When a C++ scheme uses an id above 32,767, validation now refuses it with `SchemeInvalid` and names the field. The error carries the id as a 16-bit number, so `when(65537, ...)` reports field 1, the number it wrapped to, not 65537. The spec said the error names "the member and the id"; the README now says the wrapped id is the one named. The caller sees a plausible but wrong id and has to work out the wrap.

**Options**
- **A — keep and document**: the error names the wrapped id; the README says so (done). Trade-off: a slightly misleading number for a case that cannot occur with ids written as small literals.
- **B — carry the original 32-bit id in the error**: the message names 65537. Trade-off: a change in `cpp/include` and the result type, with an arm stage run; the margin is 40 B of flash, so it may not fit.

**Recommendation**: A. The refusal itself is the fix; the id in the message is a diagnostic, and the cost of B is flash that is nearly all spent.

### Not walked

- A runtime `long` id wider than `int` passed to a C++ builder: constants fail the build under the project's `-Wall -Wextra -Werror`; a runtime value was not probed.
- Python's non-integer count raw value (`count missing`) against TypeScript's text: `_borrowed` now separates it from the not-written case, but the text for a non-integer was not compared with TypeScript.
- Java `Boolean.FALSE` for an empty-group mark: a recorded difference under decision D1 A; the owner may want it aligned (TypeScript `0100`, Java `0101`) in a later loop.

### Process finding (not a scenario)

The ticket keys of the first three commits were counted on from AZ-2451 and collided with existing Jira issues; the real tickets are AZ-2472 to AZ-2479 (`batch_02_loop25_report.md` § Ticket keys). The retrospective records the lesson.
