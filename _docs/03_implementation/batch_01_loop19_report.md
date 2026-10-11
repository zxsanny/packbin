# Loop 19 batch 01 report (wave 1: one worker per package)

Date: 2026-10-11. Workers run only their own package suite (owner preference). Nothing is committed until all six report. This file is filled as workers return.

## C# (done)

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2342 (C#) | done | `Packbin.cs` 417 → 210 (+ `SchemeOrder.cs` 258); `Walker.cs` 418 → 299 (+ `Walker.Flags.cs` 136, `Walker.Equality.cs` 34); suite 844/844 both targets after the split |
| AZ-2329 | done | pack scope carries the scheme `RoundBudget`; `PackTimes` refuses a count above `MaxRounds` naming the first body member; before: 65 536 / 70 000 rounds packed 65 541 / 70 005 bytes |
| AZ-2331 | done, AC-3 split form only | `PackFlagBit` calls `RequireNoDroppedBody`; the three hostile shapes now give an error naming `'Speed'` / `'Pt'` |
| AZ-2337 | done | `ElementValues` members only; dictionary rows relying on outer values now error naming `'A'` |
| AZ-2338 | done | `Eq(u8,300)`, string, NaN, -1, 1.5, true, `Eq(u64,-1)`, `Eq(u2,4)` refused at construction; 5.0 / 5m still build |
| AZ-2335 | tests only | list with count 0 already refused; lone scalar with count 0 packs `0100` silently |
| AZ-2332 | test only | already refused (AZ-2182) |

Final: 887/887 on net10.0 and on `-p:PackbinTarget=netstandard2.0` (baseline 844). Existing tests changed: `FlagsWhenMemberTests.Ac3_ConditionFalseBodyGiven_IsNotWritten` (direct and in-group only), `FloatConditionValueTests` (NaN, infinity, 1e30, 1.5 now construction refusals).

## Java (done)

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2342 (Java) | done | `Walker.java` 464 → 387, new `Presence.java` 138; suite output identical |
| AZ-2329 | done | limit travels in `ByteSink`; error `times: count 65536 is above the limit of 65535 rounds`; before: n = 65 536 and 1 000 000 packed |
| AZ-2331 | done, AC-3 NOT applied | error when the condition or count was written after the byte, or the count never written; the reference row W-split-false-body-given stays `0100025a00` |
| AZ-2332 | done | lone `byte[]` / `Sized` buffer refused in `times` and `repeat`; `Utf8` lone string still broadcasts; lone `bits`/`packed` not distinguishable |
| AZ-2335 | test only | list with count 0 already refused; lone scalar packs `0100` |
| AZ-2338 | done | checked by `Scalars.writeScalar` at construction; 5.0 / 1.0 Double refused (Java refuses whole doubles) |
| AZ-2339 | probe | see table below |

Final: `bash java/test.sh .` exit 0, api-check PASS.

### Java fraction-slot probe (AZ-2339)

| Value | u2 | bits | packed1 | packed2 |
|-------|----|------|---------|---------|
| Double 0.5 / 1.5 / 2.5 | refused | refused | refused | refused |
| BigDecimal 1.5 / 0.5 / 2.999 / 2.5 | **packs, truncated** (`0101`, `0100`, `0102`) | **packs** (`010200`, `010202`) | **packs** (`010200`) | **packs** (`010208`) |
| BigDecimal 1E+400 | `0100` silently | — | — | — |
| Double 3.0 / 1.0, Float 1.0 | refused | refused | n/a | refused |
| valid Integer / Long / Byte / BigDecimal("3") | pack | pack | pack | pack |

## Rust (done)

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2342 (Rust) | done | `walk/unpack.rs` 471 → 352 (+ `walk/cursor.rs` 121); `field/mod.rs` 479 → 332 (+ `field/leaf.rs` 157); 479 before and after |
| AZ-2329 | done | `check_round_cap` in the `times` arm (covers `__times_N` groups, `times` in `flags` and in a round); `max_rounds` only, not `max_slots`; n = 65 536 / 70 000 packed before, `PackError::Type` naming `pt` after |
| AZ-2331 | done, AC-3 applied literally | `check_split_bit`: a false-condition split `when` with a body given errors (one existing test rewritten); combined `flags` form unchanged |
| AZ-2333 | done | each `flags` member is its own scope; reference = TypeScript run on scheme S1 (below); S2 (no outer byte) now refused at construction, as TypeScript does |
| AZ-2332 | done | lone `Value::Bytes` refused (also count 1); `utf8` lone string stays; `repeat` takes explicit rounds so nothing to refuse |
| AZ-2335 | tests only | list with count 0 already refused; lone scalar packs `0100` |
| AZ-2338 | done | per-type source range; u8/U16(300), u16/U32(70000), i8/I16(200), u64/I8(-1), i64/U64::MAX, u2 slot 4, flag byte 256 refused at construction; Rust has no bool Value |
| AZ-2339 | probe | Rust refuses every float (whole or not) in u2/bits/packed slots; integers only |

Final: 526 passed, 0 failed (baseline 479, 47 new). Clippy clean in touched files. Existing tests rewritten: `ac3_split_form_when_false_...`, `az2311_ac2_...` (lone buffer), two `eq` tests (`eq(i8,U8(255))`, `eq(u64,I64(-1))`).

### AZ-2333 reference (S1: `flagbyte fb; flags{ group g1{v; fb byte; bit fb x}, group g2{bit fb y} }; bit fb b`)

| Row | Rust before | TypeScript | Rust after |
|-----|-------------|------------|------------|
| v3 x5 y6 b7 | `0101030303050607` | `0103030301050607` | `0103030301050607` |
| v3 x5 | `010001030105` | same | same |
| y6 | `010002` | `01010206` | `01010206` |
| b7 | `01010007` | `01020007` | `01020007` |
| v3 y6 | `010003030206` | `010103030006` | `010103030006` |

Java and C++ were not run on S1 by the Rust worker; the C++ single-member table is pinned.

Stale docs listed by the Rust worker (step 13): `_docs/02_document/components/04_rust_package/description.md` l.91, `05_cpp_package/description.md` l.72 and l.111, README l.1146 and l.1186 (say Rust shares a scope for sibling `flags` members and that split-form drops are silent).

## Python (done)

Venv `/tmp/packbin-py-l19` (python3.12; the default python3 is 3.9 and the package needs 3.10+). Final 764 passed (baseline 692).

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2330 | done | fresh `{}` scope per repeat/times round in pack and unpack. The exact T1 scheme was not found in review18; the worker built an equivalent (`u8 a; times(a, u8 k, when(k==1, u8 v), when(v==5, u8 w))`): TypeScript and Python (after) both give `010201050700`; Python before raised `TypeError` |
| AZ-2329 | done | `max_rounds` threaded into pack; n = 65 536 and 4 000 000 000 give `ValueError: times 1: 65536 rounds, the limit is 65535`; 70 000 with `with_limits(max_rounds=70000)` packs |
| AZ-2331 | done, AC-3 read like Java | raises when the `when` source / `times` count is written AFTER the byte (true or false) or the count was skipped with values; false condition with the source before the byte, and combined `flags`, stay silent. Skipped count with values now raises in combined `flags` too (reverses the T4 "owner kept it" silent drop; old test rewritten) |
| AZ-2332 | done | lone bytes / bytearray / memoryview refused in times, sized and repeat |
| AZ-2335 | tests only | list with count 0 refused; lone scalar packs `0100` silently (also inside flags) |
| AZ-2336 | done | short-list check applies to every `times`; three IndexError tests rewritten; `repeat` with an empty list for a flags member still a bare `IndexError` (loop 20) |
| AZ-2338 | done | out-of-range, `"x"`, NaN, 1.5, **5.0**, None, list, True/False refused at construction; edges 0 / 5 / 255, i8 -128, u64 2**64-1, u2 3 build |
| AZ-2339 | probe | Python refuses every fraction (also `Decimal`) and whole floats 3.0 / 1.0 in u2/bits/packed; accepts `IntEnum` members (C# refuses enums) |

20 000-case unpack-then-repack differential against a HEAD copy: `repeat`/`times` repack counts equal (1 542 / 1 542 and 17 124 / 17 124); after-the-byte schemes turn silent mismatches into `ValueError`.
Wave 2: `python/tests/hostile_support.py` `PACK_CASES` needs an entry per new `pack` case.

## TypeScript (done)

Final 712 pass, 0 fail (baseline 642); strict `tsc` exit 0; no `src` file above 446 lines.

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2329 | done | `PackState {flagBytes, maxRounds}`; n = 65 536 / 4 000 000 000 give `k: the times count is 65536, above the limit of 65535 rounds`; also inside `flags`; 70 000 with `maxRounds` 70 000 packs |
| AZ-2331 | partial by coordinator correction: AC-1 and AC-2 done, AC-3 unchanged | a clear split bit throws when its `when` condition or `times` count is written after the byte, or the count was never written with values; WS false-condition (`0100025a00`) and combined `flags` unchanged |
| AZ-2332 | done | lone Uint8Array / ArrayBuffer refused in times (also count 1) and repeat; utf8 lone string stays |
| AZ-2335 | tests only | list with count 0 already refused, in and out of `flags`; lone scalar packs `0100` |
| AZ-2338 | done | out-of-range, "x", NaN, 1.5, true, 1e30, null, undefined, `[1]` refused; 5.0, 5n, u64 max (bigint) build; **`eq(intSource, undefined/null)` ("matches an unwritten source") is gone**: 4 + 2 existing tests rewritten |
| AZ-2339 | probe | TypeScript is already as strict as C#: fractions refused in u2/bits/packed; whole 3.0 / 1.0 accepted |

### Error text pattern (TypeScript)
`<member>: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte`

## C++ (done, two specs partial)

gcc:16 `make test` and host clang `make test` pass; compile-fail 15 of 15 rejected; arm embedded stage `0 target(s) failed`: Cortex-M4F stack **448 B** of 512 B (loop 18: 456 B), AC-5 flash **8064 B of 8192 B (128 B margin left)**; M0+/M3 QEMU 241/241, s390x PASS.

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2331 | partial: AC-1 and AC-2 done, AC-3 unchanged | new `Field::late` byte (padding, `sizeof(Field)` unchanged): a flag bit whose `when`/`times` source is written after the byte and has a body given is refused (BadValue naming the member); a `times` whose count is missing from the row refuses its rounds (also in combined `flags`); `times_with_a_skipped_count` test now expects a refusal. Not covered: count set in the row but behind a clear `when` (+56 B flash) |
| AZ-2334 | done | `find_ref` accepts an empty group as a source; bytes `010107` (on) / `0100` (off) equal Rust's `when_written_tests.rs` row (read, not run) |
| AZ-2335 | partial | count 0 with a value already refused; lone scalar with count 0 packs `0100` (unchanged); hostile handler `pack_times_zero_with_values` added to `hostile_pack_cases.hpp` |
| AZ-2338 | done for integer range | out-of-range `eq` constants refused at `resolve` (SchemeInvalid; constexpr schemes fail to compile); `eq(u8, 1.5)` and `eq(u8, true)` still build (typed C++ converts to int64) |
| AZ-2339 | probe | the type system refuses fractions (`static_assert` / SchemeInvalid); no follow-up |
| AZ-2340 | done | `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` packs `01010105` (the spec's `01 01 01 05`) |

### Cross-package AZ-2331 AC-3 table (false condition, body given, split form)

| Package | Source before the byte, false | Source after the byte, false | Source after the byte, true |
|---------|------------------------------|------------------------------|-----------------------------|
| C# | error (AC-3 applied) | error | error |
| Rust | error (AC-3 applied) | error | error |
| Python | silent `0100025a00` | **error** | error |
| Java | silent | silent | error |
| TypeScript | silent | silent | error |
| C++ | silent | silent | error |

## Discovered during implementation (so far; open items go to the owner after all six report)

| Spec ref | Angle | Proposed handling | clear / unclear |
|----------|-------|-------------------|-----------------|
| AZ-2331 AC-3 vs AC-4 | AC-3 (false condition, body given, split form) contradicts the loop 18 reference row W-split-false-body-given (`0100025a00`, no error). C# applied AC-3 to the split form (combined `flags` form still no error); Java did not apply it | owner decision | unclear |
| AZ-2335 | lone scalar with count 0 packs `0100` and drops the value (C#, Java) while a list errors | owner decision | unclear |
| AZ-2331 AC-2 | skipped count with values in the non-split `flags` form is dropped silently (Java) | follow-up if wanted | unclear |
| AZ-2338 | whole-number float (5.0): C# and TypeScript-intended allow, Java refuses | align in the merged table | unclear |
| AZ-2339 | Java silently truncates BigDecimal fractions in u2/bits/packed slots | loop 20 spec | clear |
| AZ-2329 | `repeat` given more than `maxRounds` list entries still packs (unpack then refuses) | out of scope, note | clear |
| AZ-2329/2338 | hostile cases `pack_times_count_over_limit`, `construct_eq_out_of_range`, `pack_times_zero_with_values` and the Java `HostileVectorTest` mapping | wave 2 | clear |
| general | `csharp/tests/LayoutTests.cs` is 517 lines (pre-existing) | split in a later loop | clear |
| AZ-2331 AC-3 | Rust applied AC-3 literally (like C#); Java did not | owner decision | unclear |
| AZ-2329 | `max_rounds` limits pack in Rust; a scheme built with `with_limits(2, ..)` cannot pack count 3 | upgrade note | clear |
| AZ-2332 / AZ-2333 | Rust upgrade breaks: lone `Value::Bytes` in a round; sibling `flags` members bound to an earlier sibling's byte | upgrade notes | clear |
| AZ-2331 AC-3 | Python reads AC-3 like Java (only "source after the byte" is loud); C# and Rust applied it literally | owner decision | unclear |
| AZ-2338 | Python refuses `eq(u8, 5.0)`; C# allows 5.0 / 5m; Java refuses; TypeScript cannot tell 5.0 from 5 | cross-package rule | unclear |
| AZ-2339 | Python: whole floats refused, `IntEnum` accepted; C# accepts whole doubles, refuses enums | loop 20 spec | clear |
| AZ-2336 | `repeat` with an empty list for a flags member still a bare `IndexError` | loop 20 | clear |
| AZ-2331 AC-3 | TypeScript did not apply AC-3 (told to probe only); a split `when` whose source is never written with a body given stays silent; a `times` inside a `when` inside a split bit with a never-written count is not detected | owner decision with AC-3 | unclear |
| AZ-2338 | TypeScript refuses `eq(intSource, null/undefined)` (behavior removal, upgrade note); u64 numbers above 2^53 stay accepted | owner confirm | unclear |
| AZ-2339 | TypeScript is as strict as C# for fractions; no follow-up needed | none | clear |
| AZ-2331 | C++: count set in the row but behind a clear `when` still lets rounds through (`010003055a00`); fix costs +56 B flash of the 128 B margin | loop 20 decision | unclear |
| AZ-2334 | C++ empty group takes the id of the next field; a field of the same id wins for `eq` | document in the notes | clear |
| AZ-2338 | C++ `eq(u8, true)` / `eq(u8, 1.5)` still build | document | unclear |
| AZ-2335 | lone scalar with count 0 packs `0100` silently in all six packages (parity) | document, no code | clear |
| docs | the loop 18 reference doc says "count missing: bit clear" for a `times` with values; AZ-2331 AC-2 supersedes it for C++ | step 13 | clear |
| wave 2 | C++ handler `pack_times_zero_with_values` exists; `construct_eq_out_of_range` is added with the fixture line (construct stage compares counts) | wave 2 | clear |
