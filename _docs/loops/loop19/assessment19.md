# Feature assessment — loop 19

loop: 19
feature: round, flag and construction parity across the six packages (AZ-2329 to AZ-2342)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-11
**Implement pass**: wave 1 (six package workers), the AZ-2331 AC-3 follow-up (C#, Rust, Python), wave 2 (hostile cases and loaders); batch report `_docs/03_implementation/batch_01_loop19_report.md`; no completeness report.
**Verdict**: CLARIFY — 14 covered / 3 out-of-scope / 5 gap-clear / 7 gap-unclear

Input notes: the intent baseline is `problem.md`, the 14 specs, `plan19.md` and the owner decisions of 2026-10-11 (decisions 1 to 13, AC-3 option A, the five smaller points). `scenarios.md` rows 1 to 8 are all `confirmed` and covered below. **Routing: no `new-task` re-entry round (owner preference "one total review, one total test, no chained assess rounds while the hopper grows"); every gap goes to the loop 20 handoff.**

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | `pack` of a `times` count above `maxRounds` is refused before any round, five packages (C++ capacity-bound) | covered | AZ-2329 AC-1..3; `PackRoundCapTests`, `pack-round-count-cap.test.ts`, `test_pack_round_count_cap.py`, `RoundLimitsTest`, `pack_round_cap_tests.rs`; hostile `pack_times_count_over_limit`; `PackTimes`, `check_round_cap`, `ByteSink.maxRounds` | intake |
| S2 | Python rounds use a fresh scope; the T1 shape packs like TypeScript | covered | AZ-2330 AC-1..3; `test_round_fresh_scope.py`; `_pack.py`, `_unpack.py` (the exact T1 row was rebuilt as an equivalent scheme: `010201050700` in both) | intake |
| S3 | split `flag_byte` bit: loud when the body would be written but the byte left the bit clear; silent for a false condition | covered | AZ-2331 AC-1..4 (AC-3 as decided 2026-10-11); `SplitFormDroppedBodyTests`, `split-form-loud-pack.test.ts`, `test_split_form_pack_fails_loudly.py`, `SplitFormLoudPackTest`, `split_form_loud_tests.rs`, `split_form_loud_host_tests.cpp`; hostile `pack_split_*` | intake |
| S4 | a lone byte buffer in a round is refused | covered | AZ-2332; `LoneRoundValueTests`, `lone-bytes-in-round.test.ts`, `test_lone_bytes_in_round_refused.py`, `LoneBytesInRoundTest`, `lone_bytes_in_round_tests.rs`; hostile `pack_lone_bytes_in_round` | intake |
| S5 | sibling `flags` members each have their own flag-byte scope in Rust | covered | AZ-2333; `flags_member_scope_tests.rs` (reference = TypeScript run on S1) | intake |
| S6 | C++ accepts an empty group as a `when` source | covered | AZ-2334; `source_kinds_host_tests.cpp` (3); `find_ref`, `read_int` | intake |
| S7 | `times` count 0 with a list of values is refused | covered | AZ-2335; `TimesZeroWithValuesTests`, `times-count-zero-with-values.test.ts`, `test_times_count_zero_with_values.py`, `TimesCountZeroTest`, `times_count_zero_tests.rs`, `times_count_zero_host_tests.cpp`; hostile `pack_times_zero_with_values` | intake |
| S8 | Python short `times` list is a named error | covered | AZ-2336; `test_times_short_list.py`, `test_times_longer_list.py` | intake |
| S9 | a C# group element uses its members only | covered | AZ-2337; `GroupElementMembersOnlyTests` | intake |
| S10 | `eq` with an out-of-range or non-integer value is refused at construction in six | covered | AZ-2338; `EqValueConstructionTests`, `eq-value-checked.test.ts`, `test_eq_value_checked.py`, `EqValueCheckedTest`, `eq_range_tests.rs`, `eq_value_checked_host_tests.cpp`, compile-fail `when_eq_out_of_range.cpp`; hostile `eq_out_of_range` | intake |
| S11 | the fraction-slot probe table exists for five packages | covered | AZ-2339; tables in `batch_01_loop19_report.md` | intake |
| S12 | the C++ `present()` result is pinned | covered | AZ-2340; `flags_when_member_host_tests.cpp` (`01 01 01 05`) | intake |
| S13 | `run-suite.sh python` fails clearly on a broken venv | covered | AZ-2341; `.github/workflows/run-suite.test.sh`, registered in `test.yml` | intake |
| S14 | near-cap files are split without behavior change | covered | AZ-2342; suites equal before and after (C# 844, Rust 479, Java output identical) | intake |
| O1 | Go and Swift packages | out-of-scope | `problem.md` "Out of scope" line: "Go and Swift packages; a release or tag" | intake |
| O2 | a tag, a Unity IL2CPP run | out-of-scope | `problem.md` D4 | intake |
| O3 | lone scalar with count 0 packs `0100` silently | out-of-scope | owner point 1 (2026-10-11): leave, document; the six packages agree | smaller points |
| G1 | Java: a `BigDecimal` fraction in `u2`/`bits`/`packed` slots is silently truncated (`0101` for 1.5) | gap-clear | quote: "C# is strict about fractions in u2/bits/packed slots (AZ-2309)" (AZ-2339 problem) and decision 13 "probe and spec what differs" → Given a `BigDecimal` 1.5 in a `u2` slot / When packed in Java / Then it is refused naming the field | AZ-2339 probe |
| G2 | Python raises a bare `IndexError` for a `repeat` with an empty list under a flags member | gap-clear | quote: "A named error everywhere instead of bare IndexError" (decision 8) → Given a `repeat` over a flags member and an empty list / When packed in Python / Then a named error | batch_01 (Python) |
| G3 | TypeScript does not detect a `times` inside a `when` inside a split bit whose count is never written | gap-clear | quote: "pack fails loudly naming the member in all six" (AZ-2331 outcome) → Given that shape with values / When packed / Then an error naming the member | batch_01 (TypeScript) |
| G4 | C++ `Field::late` marks only the first late member of a bit: a group with two late `when`s where only the second has a body still drops it | gap-clear | same quote as G3 | batch_01 (C++) |
| G5 | `csharp/tests/LayoutTests.cs` is 517 lines | gap-clear | quote: "Source file length 500 lines (soft cap)" (quality-thresholds) → split by responsibility | review rule |
| U1 | `repeat` given more entries than `maxRounds` still packs (unpack then refuses it) | gap-unclear | question below | batch_01 (Java) |
| U2 | a `times` count written after the byte with value 0 and values given: errors in C# and Rust, other packages not probed | gap-unclear | question below | batch_01 (C#, Rust) |
| U3 | Rust keeps the error when the `when` source is absent from the row and not yet written (a derived value) | gap-unclear | question below | batch_01 (Rust) |
| U4 | C++: a count set in the row but behind a clear `when` still lets rounds through (`010003055a00`); the fix costs 56 B of the 128 B flash margin | gap-unclear | question below | batch_01 (C++) |
| U5 | whole-number floats (`5.0`, `3.0`) for `eq` and in `u2`/`bits`/`packed` slots: C# and TypeScript accept, Java, Python and Rust refuse | gap-unclear | question below | batch_01 (all) |
| U6 | `IntEnum` members are accepted in Python slots; C# refuses enums; other packages not probed | gap-unclear | question below | batch_01 (Python) |
| U7 | C++ `eq(u8, true)` and `eq(u8, 1.5)` still build (typed C++ converts to int64) | gap-unclear | question below | batch_01 (C++) |

### Gaps that need a decision (gap-unclear)

#### U1: pack of a `repeat` with more entries than `maxRounds`

**What is not decided**
The pack cap of AZ-2329 covers `times` (the count is a number, so a hostile or wrong count loops). A `repeat` takes its rounds from the list length, so memory is bounded by what the caller built; unpack of the same packet is then refused as too many rounds.
**Options**
- **A — cap `repeat` on pack too**: a list above `maxRounds` is refused naming the member. Trade-off: a packet that unpack would refuse is never produced; small code in five packages.
- **B — leave**: the caller already holds the list. Trade-off: packer and unpacker disagree on the limit.
**Recommendation**: A — the round trip must not produce a packet the same scheme refuses.

#### U2: count 0 written after the byte, with values

**What is not decided**
In the split form a `times` whose count is written after the flag byte and equals 0 while values are given: C# and Rust error (the same as count 0 with a list outside `flags`); the others were not probed for this row.
**Options**
- **A — error everywhere** (matches decision 7). **B — silent, zero rounds** (matches "count above 0" wording of the spec).
**Recommendation**: A.

#### U3: absent source in Rust

**What is not decided**
When the source of a split `when` is not in the row and not written before the bit, Rust errors; a silent drop would hide a body that a derived value might have wanted.
**Options**: **A — keep the error** (no data lost silently). **B — treat as false** (matches the other packages' "never written, silent").
**Recommendation**: B for parity, if the owner accepts a silent drop; otherwise A and change the five others.

#### U4: C++ count behind a clear `when`

**What is not decided**
Rounds are written although their count never was (`010003055a00`). The fix is +56 B of the 128 B flash margin on the Cortex-M4F target.
**Options**: **A — fix** (parity with the five other packages). **B — leave and document** (flash margin kept).
**Recommendation**: A in a loop that has no other C++ flash cost.

#### U5: whole-number floats

**What is not decided**
`5.0` equals 5 in C# and TypeScript (TypeScript cannot tell them apart) and is refused by Java, Python and Rust, for `eq` and for slot values.
**Options**: **A — accept a whole float everywhere a language has a float type** (refusing could be relaxed later, not the reverse, so this is the larger change). **B — refuse everywhere except where the language cannot tell** (JavaScript).
**Recommendation**: B (owner principle: refuse now, relax later).

#### U6: enums as slot values

**What is not decided**
Python accepts an `IntEnum` member (an int subclass); C# refuses enums for numeric fields (AZ-2309). Other packages not probed.
**Options**: **A — refuse enums everywhere**. **B — accept an integer-valued enum where the language treats it as an int.**
**Recommendation**: B for Python (it is an int); leave C# as is; document.

#### U7: C++ `eq(u8, true)` / `eq(u8, 1.5)`

**What is not decided**
Typed C++ converts these constants to int64 before the check; refusing needs an `Eq` overload per type.
**Options**: **A — add overloads** (compile error). **B — leave and document.**
**Recommendation**: B (the value is visible in source; the cost is code size on a 128 B flash margin).

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| G1 | Given a `BigDecimal` 1.5 in a `u2` slot, `bits` or `packed` item / When packed in Java / Then it is refused naming the field | "C# is strict about fractions in u2/bits/packed slots (AZ-2309)" | new loop 20 task (Java) |
| G2 | Given a `repeat` over a flags member and an empty list / When packed in Python / Then a named error naming the member | "A named error everywhere instead of bare IndexError" | AZ-2336 follow-up |
| G3 | Given a `times` inside a `when` inside a split bit with a never-written count and values / When packed in TypeScript / Then an error naming the member | "pack fails loudly naming the member in all six" | AZ-2331 follow-up (TypeScript) |
| G4 | Given a group with two late `when`s where only the second has a body / When packed in C++ / Then BadValue naming it | same quote | AZ-2331 follow-up (C++, check flash) |
| G5 | Given `csharp/tests/LayoutTests.cs` at 517 lines / When split by responsibility / Then each file under 500 lines and the same test count | "Source file length 500 lines (soft cap)" | new loop 20 task (C#) |

### Not walked

- Cross-package differential of `maxRounds` lowered by a scheme in nested rounds (C# covers it; others only the default).
- Java `repeat` with `Map` rows versus typed rows for the late-source rule (Java rows are maps).
- Python `repeat`/`times` unpack fresh-scope effect on `limit` slot counting (counts per round are unchanged; not re-measured).
