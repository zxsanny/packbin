# Feature assessment — loop 18

loop: 18
feature: cross-package hopper (construction checks, flags members, hostile pack stage, C# gap specs)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-10
**Implement pass**: batches 01 to 03 (`_docs/03_implementation/batch_01_loop18_report.md`, `batch_02_loop18_report.md`, `batch_03_loop18_report.md`); no `implementation_report_*_loop18.md` and no completeness report yet (written at the loop close). The batch reports carry the mandatory discovery tables (32 rows).
**Verdict**: CLARIFY — 19 covered / 5 out-of-scope / 3 gap-clear / 10 gap-unclear

Input notes: `scenarios.md` is absent for these specs (written in loops 11 to 18, partly before the scenario matrix); the intent baseline is the specs in `done/`, `plan18.md` and the owner decisions of 2026-10-10. **Routing decision (owner preference, memory `one-total-review-and-test`): no re-entry round.** The `gap-clear` and `gap-unclear` rows are recorded in the loop 19 handoff; `assess_round` stays 0.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | `eq(bool, v)` with `v` other than `true` is refused at scheme construction in all six | covered | AZ-2126 AC-1/AC-2/AC-3; `EqBoolTrueOnlyTests` (C#), `eq-source-kinds.test.ts`, `test_when_count_sources.py`, `eq_bool_true_tests.rs`, `EqBoolTrueOnlyTest.java`, `source_kinds_host_tests.cpp` + compile-fail; hostile `eq_bool_false` in all six loaders; `SchemeOrder`/`ref-scope.ts`/`_validate.py`/`integrity.rs`/`order.hpp` | batch_01, batch_02 |
| S2 | a `when` names an integer or a bool only; a count names an integer only | covered | AZ-2126 decided concern; same tests; Rust `check_when`/`check_count`, Java `requireWhenSource`/`requireCount`, C# `WhenSource` | batch_01 |
| S3 | a lone dictionary for a `Dict` name in a round is refused in C#, TypeScript, Python, Java, Rust | covered | AZ-2308 AC-2/AC-3; `LoneDictRoundTests`, `lone-dict-in-round.test.ts`, `test_lone_dict_in_round.py`, `LoneDictRoundTest.java`, `times_lone_value_tests.rs`; `Rounds`/`rounds.ts`/`_pack.py`/`times.rs` | batch_01 |
| S4 | Rust `times` broadcasts a lone scalar | covered | AZ-2311; `times_lone_value_tests.rs`; `slice_times` | batch_01 |
| S5 | C++ flag byte inside a `flags` member or flag-bit child is invisible to later bits | covered | AZ-2304 AC-1 to AC-4; `flag_scope_host_tests.cpp`, two compile-fail cases; `find_flag_byte`, `unpack_scoped` | batch_01 |
| S6 | C# collection members are checked at construction (width, type) | covered | AZ-2305 AC-1 to AC-4; `CollectionMemberTests`; `RequireCollection` | batch_01 |
| S7 | an all-null typed nested row counts as present under `flags` | covered | AZ-2306; `EmptyNestedRowTests`; `GroupOn` | batch_01 |
| S8 | C# `u2` slots, `bits`, `packed` follow the strict numeric rule; char, enum, object refused | covered | AZ-2309; `StrictSlotTests`; `TrySlot` | batch_01 |
| S9 | C# dictionary repack of group elements; `Bytes`/`Sized` given an int | covered | AZ-2310; `DictRepackTests`; `ElementValues`, `RequireBytes` | batch_01 |
| S10 | `Flags` as list/dict element in C#; C# in the three rings | covered | AZ-2307; `FlagsElementTests`, `ring-wiring.test.sh`; run by step 11 | batch_01 |
| S11 | hostile `pack` stage with five cases, every package handles it | covered | AZ-2194; `cases.test.sh` (25 cases, +14 corruptions); six loaders | batch_02 |
| S12 | `when`/`times`/`repeat` as a `flags` member written in all six; bytes `01 01 03 07 5a00` | covered | AZ-2120 AC-3/AC-4/AC-5; reference table; per-package tests | batch_03 |
| S13 | old clear-bit packets of that shape still unpack in all six | covered | AZ-2120 AC-5; per-package tests | batch_03 |
| S14 | a set `when`/`times`/`repeat` member that cannot be written in full fails pack naming the value | covered | AZ-2128; per-package tests | batch_03 |
| S15 | golden and route unchanged in all six | covered | AZ-2120 AC-6; existing suites | batch_03 |
| S16 | loop 17 D2, D4, E3, E4, E5, E8, E9, E11 decisions | covered | S6 to S10 above | handoff17 |
| S17 | loop 17 D8 (IL2CPP) and D11 (AC-7 2x) | covered | owner decisions 1 and 4; documented in step 13 (README sentence, AC-7 amendment) | plan18 |
| S18 | AZ-2135 closed (Python by AZ-2230, C# loop 17, C++ follow-up AZ-2304) | covered | AZ-2135 result section | batch_01 |
| S19 | typed `Unpack` of a `repeat`/`times` round throws `InvalidCastException` (F17) | out-of-scope | AZ-2092 `### Excluded`; carried | batch_01 #12/#30 |
| S20 | C++ error carries one field id (the `when` id, not the source id); error text differs per package | out-of-scope | owner decision "error kind and label are C15" | batch_01 #6, #17; batch_03 #32 |
| S21 | C++ and Rust typed rows cannot express some pack-error rows | out-of-scope | AZ-2194 `Not run by` lists; typed rows are static | batch_02, batch_03 #31 |
| S22 | `invalid_utf8` vectors: C++ borrows UTF-8 unchecked | out-of-scope | loop 10 owner decision (C15 wording), standing concern | batch_02 #21 |
| S23 | AZ-2068 (C++ AVR build) | out-of-scope | optional stretch, unclaimed | plan18 |
| G1 | a Rust `times` count above 0 whose bit is clear unpacks to a row that cannot repack (`missing pt`); same in all six | gap-clear | quote: "Where a set group cannot be written in full, pack fails loudly naming the missing value" (AZ-2128 Outcome) → Given the row unpacked from `0104a60100`, When repacked, Then pack fails naming `pt` (today's behavior; add the README upgrade note only) | batch_03 #23 |
| G2 | pytest venv `/tmp/packbin-pytest` is broken and `run-suite.sh` checks only `bin/pytest` | gap-clear | quote: "Missing test dependency → add to manifest and install" (coderule.md) → Given a venv without a usable pytest, When `run-suite.sh python` runs, Then it rebuilds the venv or fails with a clear message | batch_01 #14 |
| G3 | `Walker.Counted.cs` is 480 lines (cap 500) | gap-clear | quote: "Source file length 500 lines (soft cap)" (quality-thresholds.md) → split by responsibility before the next addition | batch_01 #16 |
| U1 | a lone byte buffer for a `Bytes`/`Sized` name in a round is broadcast by TypeScript, Python, Java, Rust and refused by C# | gap-unclear | question below | batch_01 #1 |
| U2 | TypeScript packs a `Map` given for a dict outside a round as an empty dictionary | gap-unclear | question below | batch_01 #2 |
| U3 | sibling `flags` members: separate flag-byte scopes in C++, TypeScript, Java; one shared scope in Rust | gap-unclear | question below | batch_01 #3 |
| U4 | C++: a group under `flags` whose only children are `flag_byte`/`flag_bit` is never present on pack | covered (closed after the finding) | the C++ `present()` change of AZ-2128 (wave 3) counts `flag_bit` and nested `flags` heads: a probe at HEAD packs `flags(group(flag_byte(0), flag_bit(0,x)))` as `01 01 01 05` and `flag_byte(0), flags(0, flag_bit(0,p), q)` as `01 01 03 05 06`; not pinned by a test yet (handoff 19) | batch_01 #4, step 13 probe |
| U5 | C++ refuses a `when` naming an empty group even for `true`; Rust accepts it as a bool source | gap-unclear | question below | batch_01 #5 |
| U6 | a `times` count 0 with a non-empty list: error (C#, TypeScript, Python, Java, Rust, and now C++ outside `flags` too) | gap-unclear | question below | batch_03 #22 |
| U7 | a `times` whose count field was skipped: bit clear and body values dropped without an error | gap-unclear | question below | batch_03 #24 |
| U8 | a `when` nested in the body of a `flags`-member `when` is decided before the outer body; a `when` with a false condition drops a given body silently | gap-unclear | question below | batch_03 #26, #27 |
| U9 | Python: a short `times` list outside `flags` is a bare `IndexError`; only a `flags` member names the value | gap-unclear | question below | batch_02 #19, batch_03 #29 |
| U10 | C# `ElementValues`: a group element inherits outer-row values of the same name | gap-unclear | question below | batch_03 / AZ-2307 |
| U11 | are fractions in `u2` slots, `bits`, `packed` rounded by the other five packages (decision 8 covered C# only)? and the AZ-2305 member-type rule (float members for integer fields, interfaces accepted) | gap-unclear | question below | batch_01 #10, #13 |

### Gaps that need a decision (gap-unclear)

#### U1: a lone byte buffer in a round

**What is not decided**
A single byte array given for a `Bytes` or `Sized` name inside `repeat`/`times` is copied to every round by TypeScript, Python, Java and Rust, and refused by C# (AZ-2182, owner option A: a lone collection is refused). The same row gives different bytes or an error depending on the language.
**Options**: A refuse everywhere, with a message that says to wrap one buffer per round in a list (breaks users of four packages); B broadcast everywhere (C# changes, reverses AZ-2182 for byte buffers).
**Recommendation**: A for the same reason as the lone dictionary (decision 6): refusing can be relaxed later, accepting cannot be withdrawn.

#### U2: a `Map` as a dict in TypeScript
**What is not decided**: a JavaScript `Map` given for a dict name outside a round packs as an empty dictionary (silently loses the entries).
**Options**: A refuse a `Map` for a dict name with a clear error; B accept a `Map` and read its entries.
**Recommendation**: A (small, no new surface).

#### U3: sibling `flags` members and flag-byte scope
**What is not decided**: a flag bit in the second member of one `flags` cannot see a flag byte in the first member in C++, TypeScript and Java; Rust lets it.
**Options**: A change Rust to separate scopes (like three packages); B change the three to one shared scope.
**Recommendation**: A: schema.md says a flags member is a conditional scope.

#### U4 (closed): a flag-bit-only group under `flags` in C++
**Closed by the wave 3 `present()` change** (probe in the table row above); only a pinning test is left (handoff 19).
**What is not decided**: `flags(group(v, flag_byte(0), flag_bit(0, x)))` with only `x` set drops it in C++ (`0100`); Rust and TypeScript write `0100010105`.
**Options**: A follow-up spec: a flag bit child makes its group present; B document the limit.
**Recommendation**: A (same-bytes rule).

#### U5: an empty group as a `when` source in C++
**What is not decided**: C++ refuses `when(eq(emptyGroup, true))`; Rust and the spec text ("bool or empty-group id") accept it.
**Options**: A accept `eq(group<M>(id), true)` in C++; B keep the refusal and document it.
**Recommendation**: A.

#### U6: `times` count 0 with values given
**What is not decided**: the loop 18 rule makes it a pack error in `flags`; C++ now also refuses it outside `flags` (silently skipped before).
**Options**: A keep the error everywhere; B only inside `flags` (revert the C++ change).
**Recommendation**: A: every other loud-pack rule since loop 11 does this.

#### U7 and U8: silent drops left in the flags-member rule
**What is not decided**: (U7) a `times` whose count field was skipped drops its values silently; (U8) a `when` with a false condition drops a body value, and a `when` inside a `flags`-member `when` body is decided before that body.
**Options**: A keep (consistent with unpack and with a `when` outside `flags`); B make a given-but-unreachable value an error.
**Recommendation**: A: refusing can be added later; these rows describe values the reader would not read either.

#### U9: Python short `times` list
**What is not decided**: a list shorter than the count outside `flags` raises a bare `IndexError`.
**Options**: A named error everywhere (changes three existing tests); B leave.
**Recommendation**: A, one rule.

#### U10: C# group element inherits outer values
**What is not decided**: a member a group element lacks is filled from the outer row's value of the same name (fixed only for flags elements).
**Options**: A members-only rule for group elements too; B keep.
**Recommendation**: A.

#### U11: the other packages and slot rounding; member-type rule
**What is not decided**: whether TypeScript, Python, Java, Rust, C++ round a fraction in a `u2` slot, `bits` or `packed` item; and the exact AZ-2305 rule (float members for integer fields accepted, interfaces `IList<E>` accepted).
**Options**: A probe the five packages and spec what differs; B accept the rule as built.
**Recommendation**: A for the probe, B for the rule.

### Not walked

- A `flags` member holding a continuing (unanchored) group, and `repeat` or `times` nested inside a group inside a `flags` member in every package (the reference table has no case).
- `times` count taken from a field inside the same `flags` member group (only a count before the `flags` is in the table).
- Typed multi-round rows in C# (`U8<T>` takes a scalar; one round only).

### Harness gaps

- none: batch reports 01 to 03 carry `## Discovered during implementation`; no `scenarios.md`, `problem.md` or `implementation_report_*_loop18.md` exists yet for this loop.
