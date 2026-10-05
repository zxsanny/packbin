# Batch Report

**Batch**: 1 (csharp, typescript, rust and java as one wave of parallel workers; python by the parent; two review fix rounds plus a Java third)
**Tasks**: AZ-2079_csharp_bool_rule_flag_limit, AZ-2080_typescript_bool_flag_limit, AZ-2082_rust_flag_bits_bool, AZ-2083_python_bool_flag_limit, AZ-2089_java_forward_refs_bool
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2079_csharp_bool_rule_flag_limit | Done | 9 files (4 src, 4 tests, driver) | 194/194 pass | None |
| AZ-2080_typescript_bool_flag_limit | Done | 10 files (5 src, 4 tests, driver) | 101 pass, 0 fail, 3 todo (AZ-2090 construct vectors) | None |
| AZ-2082_rust_flag_bits_bool | Done | 15 files (9 src, 4 tests, lib.rs, driver) | 121/121 pass | `slice_times` drop left to AZ-2086 (below) |
| AZ-2083_python_bool_flag_limit | Done | 4 files (1 src, 2 tests, driver) | 94/94 pass | None |
| AZ-2089_java_forward_refs_bool | Done | 15 files (6 src, 8 tests, driver) | java/test.sh 0 failures | Nested rounds refused until AZ-2127 |

Shared (parent): `.github/workflows/language-pair.sh` gains the `boolflag` (`0100`) and `booltrue` (`0101`) rings over all six languages; `drivers/handoff.cpp` and `drivers/handoff.py` gain both commands; `README.md` bool rule, scheme rules and upgrade notes; `fixtures/hostile/README.md` notes.

Placement rule in every package (C++ precedent, `order.hpp` `check_shape`): a `bool` or an empty group only as a direct child of `flags` or a flag-byte bit; the flag bit is set only for `true`; a ninth bit in one flags byte fails construction.

## Code Review Verdict: PASS_WITH_WARNINGS (after one fix round)

Round 1, four fresh reviewers: C# FAIL, Java FAIL, Rust PASS_WITH_WARNINGS, TypeScript/Python/shared PASS_WITH_WARNINGS. Escalated to the owner, who chose (2026-10-05):

- C# F1 (High): AC-7 counts typed `int` U2 / `byte[] = []` children as present, so a mixed flags group turned on and `PackGroup` skipped a null sibling, writing an unreadable packet. **Fail loudly**: when a group's bit is on, pack throws `ArgumentException` naming the missing value (also inside a nested group).
- Java F1 (High): flag bits inside `repeat` were decided from the whole per-row list, so `repeat(flags(bool))` packed clear bits. **Fixed**: bits use the round's value.
- Mediums, **all fixed in this loop**: C# nested group presence; Rust split bits under a top-level group / flags member, the motion pin test, group-under-bit and bit-in-group presence; Java aligned per-round lists on unpack (`null` for a skipped round), `seen` cleared per round (repeat and times), count/`when` targets limited to integer or bool fields (C++ `is_count_source`).
- `when(eq(bool, false))` (C#, TS, Python): **follow-up AZ-2126**, rule "refuse any value other than `true` at construction, all packages".

Follow-up tickets filed in Jira and `todo/` (epic AZ-2069): AZ-2126 (`eq` on a bool accepts only `true`), AZ-2127 (Java nested rounds), AZ-2128 (flag group presence parity).

Lows fixed: construct-vector tests assert the rule's message (C#, TS, Python); Java dead duplicate-id check removed; Rust map bool other than 0/1 is `PackError::Type`; Rust bits bind per flag-byte read like C++; `booltrue` leg added to the cross-language ring.

Round 2 re-review (C#, Java, Rust): C# PASS_WITH_WARNINGS (F1, F2, F6 verified fixed, no regression); Rust PASS_WITH_WARNINGS (F1–F5 verified fixed, no regression; 67M short-input unpack fuzz with no panic); Java FAIL on a new High: a `times` nested in a `repeat`/`times` round read every inner round from item 0 (silent wrong values; HEAD threw an NPE or was already corrupt). Owner decision: Java refuses a `repeat`/`times` inside a round at construction now (round 3, red-first tests), per-round nested lists in **AZ-2127**. Round 3 also made Java unpack padding linear (64 KB packet into an ignoring setter was 4.5–30 s under C1; now under 1 s, tested) and restored a sometimes-zero-width AC-3 element test.

Remaining Mediums, owner decision **follow-up AZ-2128**: a flags group whose only present values sit in child kinds the presence check ignores drops them silently (C#: nested `Flags`/split bit/`When`/`Repeat`/`Times`; Java: the same plus `u2`; Rust map API: `u2`/`sized`/`bits`/`packed`/nested group/`when`). Pre-existing in all three. Lows fixed by the parent: Rust `group()` doc narrowed to what `group_on` counts, duplicate match arm merged; C# value-rule tests assert the rule text; README notes C# also clears non-`true` values.

Reproducing tests changed (reviewed, guards mutation-checked):
- C#: `Ac1_ZeroWidthBoolRepeatBody_DoesNotHang` removed (bool repeat body is now illegal); the hang guard stays in `Ac1_ZeroWidthRepeatBody_ReturnsTrailingBytes` and the `zero_progress_repeat_when` vector.
- Java: `HostileUnpackTest` AC-1 times test and `ZeroWidthElementTest` AC-3 rewritten to legal shapes; with each guard removed in a scratch copy they fail.
- Java `FlagStateTest.repeatRoundKeepsItsOwnFlagByte` expected `a` changes from `[7, 9]` to `[7, null, 9]` (aligned lists).

## Test Suite

- C# 194 passed; TypeScript 104 (101 pass, 3 todo); Python 94; Rust 121; Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: user, nested, boolflag, booltrue, session and position rings pass across all six languages
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {csharp,typescript,python,rust,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `bash .github/workflows/publish-gate.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `language-pair.sh` (host toolchains, macOS SDK sysroot)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `when(eq(boolId, false))` can never match on unpack once `false` is absent; C#/TS pack still match and write the body | none | AZ-2126 (owner decision: refuse at construction) | clear |
| 2 | TypeScript `new Scheme(...)` public constructor skips every `scheme()` check | none | Make the constructor internal (API change, needs a decision) | unclear |
| 3 | TypeScript: a bool under a split bit inside `repeat` collects only set rounds; `fb` lands in the row | AZ-2091 area | Fold into AZ-2091 | unclear |
| 4 | C#: a continuing group whose own `bool? Mark = false` still turns its bit on; with F1 it now throws naming the first missing child | none | Small follow-up: apply true-only to a non-empty group's own bool member, or ignore it | unclear |
| 5 | C#: a `When` inside a flags group is not checked by the group-value rule | AZ-2120 | AZ-2120 | clear |
| 6 | C#: an empty nested-row group under `Flags` builds but its bit can never be set | none | Reject zero-child nested-row groups everywhere, or leave | unclear |
| 7 | Rust: values under `when` / `flags` / `group` inside a `times` round are dropped (`slice_times` slices only direct children); map form has no per-round holes | AZ-2086 | Needs per-round rows (AZ-2086, typed `times` binds `Vec<E>`) | unclear |
| 8 | Rust: a bit after a `when` that also reads the same-named byte binds to the outer byte (schema.md); C++ `find_flag_byte` binds to the inner one | schema.md split form | Raise for C++ | clear |
| 9 | Java: a count naming a `bool` constructs (C++ allows it) but Java pack/unpack do not turn a bool into a 0/1 count | F4 | Decide across packages: bool count means 0/1, or refuse | unclear |
| 10 | Java: a nested-row group inside a repeat reuses the per-round list as the child row; nested repeat/times inside a round write into the outer lists | task 32 | Leave to AZ-2101 / follow-up | clear |
| 11 | Python split form: `_FlagBit` → `_Bool` unpack is `pass`; a flag byte listed without its bits constructs and drops the bool | AZ-2100 | Recorded on AZ-2100 | clear |
| 12 | TS / Rust / Java: a truthy value other than `true` (TS `1`, Java non-Boolean) clears the bit silently; Rust now errors | none | README upgrade note; fail-loudly belongs to AZ-2088-style tasks per package | clear |
| 13 | Java: a `repeat` inside a `list`/`dict` element that sits inside a round still builds (the element is its own row) and round-trips | AZ-2089 round 3 | Keep (same as C++ element scope) | clear |
| 14 | Java: no legal shape remains in which a `times` body reads nothing for only some packets; the guard is covered by the always-empty bodies | AZ-2074 | None | clear |
| 15 | Java: a count naming a `bool` builds (C++ reads it as 0/1) but Java pack/unpack fail | AZ-2126 | Recorded as an open concern on AZ-2126 | unclear |
| 16 | Rust: a bool under a flag bit inside a `when` that is not taken sets a stray bit in the outer byte (same as C++ `pack_flag_byte`), or errors for a non-0/1 value | none | Leave; minor | clear |

## Commit

`[AZ-2079] [AZ-2080] [AZ-2082] [AZ-2083] [AZ-2089] Bool only inside flags` — body: one line + `Loop: 12`

## Next Batch: All tasks complete
