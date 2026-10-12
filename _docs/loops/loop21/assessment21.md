# Feature assessment — loop 21

loop: 21
feature: one slot rule, parity rules U1 to U9, C# integer types and row rounds, empty round bodies refused (AZ-2373, AZ-2381 to AZ-2394)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-12
**Implement pass**: wave 1a (TypeScript reference, C++, C# pass 1), wave 1b (Python, Java, Rust, C# pass 2), wave 2 (fixtures and six loaders); batch report `_docs/03_implementation/batch_01_loop21_report.md`; reference `_docs/03_implementation/reference_loop21_slots.md`.
**Verdict**: CLARIFY — 13 covered / 2 out-of-scope / 3 gap-clear / 6 gap-unclear. No re-entry round (owner rule: open angles go to the loop 22 handoff).

Input notes: intent baseline is `problem.md` (D1 to D10), the 15 specs, `plan21.md` and the owner decisions of 2026-10-12 (U1 to U9 option A, U10 option B). `scenarios.md` rows 1 to 12. Total review not yet run when this was written; its findings are rows G2 to G6.

### Coverage matrix

| id | scenario | status | evidence (AC + test + code) | source |
|----|----------|--------|-----------------------------|--------|
| S1 | one slot-width rule for a round in six packages; pack at `maxSlots` unpacks | covered | AZ-2382 AC-1/AC-2, AZ-2381; `round-slot-width.test.ts`, `test_round_slot_width.py`, `RoundSlotWidthTest`, `RoundSlotWidthTests`, `round_slot_width_tests.rs`; `Rounds.width`, `round_width`, `_round_width`; hostile `pack_round_slots_*` (Java nested-row exception: G3) | U1, U2 |
| S2 | short optional list under `flags` refused (`repeat`) | covered | AZ-2383; `repeat-short-optional.test.ts`, `test_repeat_short_optional.py`, `RepeatShortOptionalTest`, `ShortOptionalListTests`; hostile `pack_flags_short_list` (Rust, C++ not run) | U3 |
| S3 | split-bit `times` with count after the byte and an absent body packs a clear bit | covered | AZ-2384; `ClearBitProbesTest`, `SplitTimesClearBitTests`, `loop21_parity_probes_tests.rs`; hostile `pack_split_times_absent_body` (C++ excluded) | U4 |
| S4 | C++ packs a late `when` in a bit body when another member sets the bit; Rust too | covered | AZ-2385; `late_source_host_tests.cpp`, `late_when_in_bit_body_tests.rs`; `pack.cpp`, `flag_bits.rs`; hostile `pack_late_when_in_bit_body` | U5 |
| S5 | count above 0 behind a clear `when`, no rounds, refused (split bit and `flags`) | covered | AZ-2386; six pins; hostile `pack_count_one_clear_when` | U6 |
| S6 | `bits`/`packed`/`sized` count behind a clear `when` refused with a value | covered | AZ-2387; reference rows 53-55; hostile `pack_*_count_clear_when` | U7 |
| S7 | C# exact integer types from unpack; whole floats refused for integer fields | covered | AZ-2373; `ExactIntegerTypeTests`; `Walker.Scalars.cs`, `Walker.Numbers.cs` | decision 6 of loop 20 |
| S8 | typed C# rounds bind to a collection of rows; builds iff it binds | covered | AZ-2388; `RowRoundTests`, `RowRoundMemberTests`; `RowRounds.cs` | U8 |
| S9 | C# dict member in a round that cannot hold rounds refused at build | covered | AZ-2389; `RoundCollectionMemberTests` | U9 |
| S10 | empty `times`/`repeat` body refused at build in six; F33 shape under 1 s | covered | AZ-2390; `empty-round-body.test.ts` and five siblings; hostile `construct_empty_*` | F33 |
| S11 | `sliceRound` and list-item scope no longer copy the enclosing scope | covered | AZ-2391; `round-scope-cost.test.ts`; `rounds.ts` `sliceRound`, `overlay` | F34 |
| S12 | hostile loaders pin the refusal rule or message in Python, Java, Rust, C++ | covered | AZ-2392; `hostile_refusals.py`, `HostileRefusals.java`, `refusals.rs`, `kRefusals` (each shown to discriminate) | G2, G3 |
| S13 | C# count text, lone `byte[]` in a repeat, `WithLimits` overload | covered | AZ-2393; `CountTextAndLimitsTests` | G4, A7 |
| O1 | Go, Swift, AZ-2068, a tag, slow-test trimming | out-of-scope | `problem.md` D7 | intake |
| O2 | message and exception-class parity | out-of-scope | owner decision U10 option B | U10 |

### Gaps that are clear (gap-clear)

| id | gap | quoted line | proposed AC |
|----|-----|-------------|-------------|
| G1 | C++ empty-round check does not look through `when` | `problem.md` D8: "refuses a round body with no *member* looking through `when` and groups" | Given `times(1){ when(...) {} }` When built in C++ Then `SchemeInvalid` (flash permitting) |
| G2 | Python unpack memory after removing the first-round surcharge | `AZ-2381`: "the README sentence about the surcharge is removed" | measure in step 14; README memory note |
| G3 | AZ-2373 text "37 tests" is 7 | batch report row 10 | correct the spec |

### Gaps that need a decision (gap-unclear)

| id | question | options |
|----|----------|---------|
| U11 | `bits`/`packed`/`sized` count in the row behind a clear `when`, no value: refuse like the `times` shape? | A refuse in six; B keep the clear bit |
| U12 | C# `List<double>` for an integer list builds and unpacks but pack refuses | A refuse at construction (breaking); B accept whole floats in list elements |
| U13 | Rust drops per-name `repeat` lists with no `__repeat__` groups silently | A refuse; B exempt Rust in the AC |
| U14 | Python's equal-length rule for `repeat` (rows 30, 31, 38) vs the five others | A align Python; B align the five |
| U15 | `times` and a short list under `flags` (TypeScript accepts, Rust refuses the list form) | A refuse in all; B accept in all |
| U16 | Java nested-row group counts 1 slot, TypeScript counts members | A align Java; B README exception, Go copies TypeScript |

## Not walked

Fixture schema check for the older TypeScript `row4_packed_*` width argument; C++ shared `Late` flag corner (refused id); Rust `times` list-form guard messages.
