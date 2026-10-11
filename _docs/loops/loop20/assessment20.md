# Feature assessment — loop 20

loop: 20
feature: pack output budget and the loop 19 parity follow-ups across the six packages (AZ-2354 to AZ-2367)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-12
**Implement pass**: wave 1a (TypeScript reference, C++), wave 1b (C#, Python, Java, Rust), wave 2 (hostile cases), the review fix pass; batch reports `_docs/03_implementation/batch_01..04_loop20_report.md`; review `_docs/loops/loop20/review20.md`; no completeness report.
**Verdict**: CLARIFY — 14 covered / 3 out-of-scope / 5 gap-clear / 10 gap-unclear

Input notes: intent baseline is `problem.md`, the 14 specs, `plan20.md`, the owner decisions of 2026-10-11 (1 to 9, all option A) and the AZ-2358 answer (option A: document now, spec the fix). `scenarios.md` rows 1 to 11 are covered below. **Routing: no `new-task` re-entry round** (owner preference, memory `one-total-review-and-test`: do not chain assessment rounds while `todo/` grows). The gap rows go to `_docs/loops/loop21/handoff21.md`; the unclear rows are asked as one decision batch, recommended first, at the start of loop 21.

### Coverage matrix

| id | scenario | status | evidence (AC + test + code) | source |
|----|----------|--------|-----------------------------|--------|
| S1 | one `maxBytes` budget per pack call (default 16 MiB, raisable); the lone `utf8` under a capped `times` is refused in ms and under 256 MB | covered | AZ-2354 AC-1, AC-3, AC-5; TS `pack-output-budget.test.ts` + `pack-out.ts`; Python `test_pack_output_budget.py` + `_pack_limits.py`; Java `PackBudgetTest` + `ByteSink.java`; C# `PackOutputBudgetTests`, `PackOutCapTests` + `PackOut.cs`; Rust `pack_output_budget_tests.rs` + `walk/pack_out.rs`; hostile `pack_lone_utf8_under_times_over_budget` | decision 1 |
| S2 | a list element holding a `times` is refused at the default and packs with a raised budget | covered | AZ-2354 AC-2 (40 items of `u64`); same tests; Rust has no equivalent (no `times` in a list element, skip with reason); hostile `pack_element_times_over_budget` | decision 1 |
| S3 | `maxSlots` is charged per round on pack with unpack's width, slots before bytes | covered | AZ-2354 AC-4; `PackSlotBudgetTests`, `pack_output_budget_tests.rs`, `PackBudgetTest`; hostile `pack_slots_over_limit` | decision 1 |
| S4 | `repeat` above `maxRounds` is refused on pack | covered | AZ-2355; `pack-repeat-round-cap.test.ts`, `test_pack_repeat_round_cap.py`, `RepeatRoundCapTest`, `PackRepeatRoundCapTests`, `pack_repeat_cap_tests.rs`; `rounds.ts`, `Walker.Rounds.cs`, `walk/times.rs`; hostile `pack_repeat_over_limit` | decision 2 |
| S5 | count 0 after the byte: list refused, lone scalar silent, in six | covered | AZ-2356; TS/Java/C# pins, Python and Rust fixes (`010000`), C++ `times_count_zero_host_tests.cpp`; hostile `pack_split_count_zero_after_byte_list`/`_scalar` | decision 3 |
| S6 | C++ count behind a clear `when` is refused (`times`, and after the review `bits`/`packed`/`sized`) | covered | AZ-2357 AC-1/AC-2; `split_form_loud_host_tests.cpp`, `held_count_nested_late_host_tests.cpp`; `order.hpp` `mark_held`, `pack.cpp` `ref_value`; arm flash 8160 of 8192 B | decision 5 |
| S7 | C# whole-number floats refused for `eq` and `u2`/`bits`/`packed` slots | covered | AZ-2358 AC-1/AC-2 (eq and slots); `EqValueConstructionTests`, `StrictSlotTests`; `Walker.Numbers.cs`, `SchemeOrder.cs`; the integer-field part is O3 | decision 6 |
| S8 | enum slot values pinned per package | covered | AZ-2359; `loop20-parity-pins.test.ts`, `test_loop20_parity_pins.py`, `ParityPinsTest`, `EnumSlotValuesTests`, `loop20_parity_pins_tests.rs` | decision 7 |
| S9 | combined `flags` skipped count with values refused naming the member, six | covered | AZ-2360; `split-form-loud-pack.test.ts`, `test_split_form_pack_fails_loudly.py`, `ParityPinsTest`, `FlagsSkippedCountTests`, `loop20_parity_pins_tests.rs` (`Form::Combined` after review A4), `split_form_loud_host_tests.cpp`; `flag-bits.ts`, `Walker.Flags.cs`, `walk/flag_bits.rs`; hostile `pack_flags_skipped_count_with_values` | decision 9 |
| S10 | Java `BigDecimal` fractions, u64 `sized`/`bits` counts, `ByteSink` growth | covered | AZ-2361; `CountsFractionsSinkTest`; `VarFields.java`, `Scalars.java`, `ByteSink.java` | G1, F29, F30 |
| S11 | Python empty `repeat` under `flags`: no bare `IndexError` (optional leaf, and after the review a required leaf) | covered | AZ-2362; `test_loop20_parity_pins.py`; `_pack_rounds.py` | G2 |
| S12 | TypeScript `times` in a `when` in a split bit | covered | AZ-2363 (already refused since loop 19, review B2); `loop20-parity-pins.test.ts`; `flag-bits.ts` `countNeverWritten` | G3 |
| S13 | C++ every late member of a bit is marked (two late `when`s, nested `when`/`flags`/`times`) | covered | AZ-2364 + review C1; `late_source_host_tests.cpp`, `held_count_nested_late_host_tests.cpp`; `order.hpp` `mark_late`, `pack.cpp` `under_clear_when` | G4 |
| S14 | typed C# round unpack returns an error result; round collection checks equal the binding predicate; files split under 500 lines; hostile cases replayed by six loaders | covered | AZ-2366 (AC-2 corrected in review A1), AZ-2365, AZ-2367; `TypedRoundUnpackTests`, `RoundCollectionMemberTests`, `LayoutCountedTests`, `bound_collections.rs`; `RowBinding.cs`, `FieldBinding.cs`; `fixtures/hostile/check-cases.sh` ok: 40 | F17/F27, G5 |
| O1 | Go and Swift packages, a release or tag, AZ-2068 (C++ AVR) | out-of-scope | `problem.md` D6 and "Out of scope": "Go and Swift packages; a release or tag" | intake |
| O2 | the session layer under the budget | out-of-scope | `problem.md` "Out of scope": "the session layer (it wraps a packed packet ...)" | intake |
| O3 | whole-number floats for plain integer fields in C# (u8..i64) | out-of-scope | owner answer 2026-10-11 (option A): document now, AZ-2373 for loop 21 | decision 6 |

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed task |
|----|------------------------------|--------------|---------------|
| G1 | Given the README limits section and the upgrade notes / When step 13 runs / Then they cover `maxBytes` (`withLimits`, `with_limits(max_bytes=)`, C# optional parameter, Rust `with_max_bytes`, Java `withMaxBytes`), slots and the `repeat` cap on pack, the one accepted row now refused (plain `times`, count behind a clear `when`, count 0, no rounds), the AZ-2358 integer-field gap, typed non-nullable members counting as given (review A3), the 255-entry C++ link limits, the C# round member rule and the C# binary-breaking `WithLimits` (A7), U3/U7 text; and the stale component docs (`01_csharp_package/description.md` line 145, `05_cpp_package/description.md` line 128, `tests.md`, traceability matrix, `table.hpp` comments) are corrected | "README: say that a lone string is repeated `n` times and that the packet length is the caller's to bound" (F28 remediation) and the loop 19 handoff "Stale docs" | step 13 (this loop) |
| G2 | Given a hostile `pack` case that must be refused for a specific rule / When replayed by the Python, Java, Rust or C++ loader / Then the loader pins the rule that fired (a message table like the TypeScript `PACK_REFUSAL`), not only that pack refused | AZ-2367 AC-1 "each package gives the case's expected outcome" and review B4/C5 | loop 21 task |
| G3 | Given the C++ AZ-2356 pin and `pack_split_count_zero_after_byte_list` / When run / Then they exercise the count-0 rule and not the late rule (a shape where `n` is written before the bit, if one exists) | review C4 | loop 21 task (C++, no flash) |
| G4 | Given a C# `times` count above `int.MaxValue` or a lone `byte[]` in a `repeat` above `maxRounds` / When packed / Then the reference wording `{member}: the times count is N, above the limit of M rounds` / the lone-buffer error is raised | AZ-2354 Outcome "the same typed error as the count cap ... naming the member" and review A5/A6 | loop 21 task (C#) |
| G5 | Given AZ-2373 / When implemented / Then C# unpack returns exact integer types and integer fields refuse whole floats | owner answer 2026-10-11 | `todo/AZ-2373` (written) |

### Questions for the owner (gap-unclear)

| id | question | options | recommendation |
|----|----------|---------|----------------|
| U1 | Python's unpack charges 8 more slots per name for the first round of each run (README line 1192), so a packet pack writes at exactly `maxSlots` is refused by Python's own unpack. Align Python unpack to the other packages, or document? | A align Python unpack (a behavior change for hostile packets); B document the gap | A, in a loop without other Python unpack work |
| U2 | The width a round charges differs between packages (Rust counts group, `flags` and flag-byte names; Python never counts an empty group's name and counts duplicate leaves twice; TypeScript counts an empty group). Align all to the TypeScript rule? | A align all six | A, with the Go package so Go starts from one rule |
| U3 | A short list in an optional flags position (`{w:[1,2], v:[5]}`): TypeScript packs `010101050200`, Python refuses `repeat fields must have equal lengths` | A refuse everywhere; B pack as TypeScript | A |
| U4 | Java refuses a split-bit `times` whose count is above 0 written after the byte with the body absent or `[]` (pre-existing); TypeScript and Python pack a clear bit | A pack a clear bit everywhere; B refuse everywhere | A (the body is absent, nothing is lost) |
| U5 | C++ refuses a direct late `when` in a bit body even when another non-late child already sets the bit; TypeScript packs that row | A pack (as TypeScript); B refuse | A, if it costs no flash (margin is 32 B) |
| U6 | U4 row (count 1 behind a clear `when`, no rounds): Python packs `0100025a00`, C++ refuses (before and after loop 20) | A refuse everywhere; B pack everywhere | A |
| U7 | `bits`/`packed`/`sized` counts behind a clear `when`: C++ and TypeScript refuse; C#, Python, Java and Rust not probed | A probe the four and align to refuse | A |
| U8 | Typed C# rounds bind only to object-typed or collection members; a scalar member in a round always returns `ShortPacket` (D5 left typed round binding out) | A bind typed rounds to a collection of rows (the Rust direction); B keep and document | A, a spec of its own before the Go package |
| U9 | A dict member in a C# round that cannot hold the rounds still builds (a loop 18 test pins it for pack) and unpack returns `ShortPacket` | A refuse at construction as for list members; B keep | A |
| U10 | Message and limit parity: Java and Rust keep the loop 19 `times` cap text; older Python/Java/Rust messages name a field by id; the Python and C# limit validators have no 2^53 bound | A unify wording and bounds in one cleanup task; B accept | B (low value; do it when a loader pins messages, G2) |

### Not walked

- Slow tests: Rust AC-4 rows 20 s in debug (0.8 s in release), Python suite +20 s (25.7 s), the hostile slots case 8 s (Rust debug), the C# `Ac10TimingTests` flake once at 1076 ms in a full run and about 10% slower small `times` packs; decide after the one total run (step 11) shows the real CI cost.
- The ESP-IDF and Pico builds with the 32 B flash margin left (any C++ core edit in loop 21 needs a saving first).
- `maxBytes` above 2 GiB in Java and Rust on a 32-bit `usize`; Python `mypy --strict` finding at `_pack.py:410` (CI does not run mypy).
- Cross-language ring replay of the new limits (the rings run unchanged fixtures).
