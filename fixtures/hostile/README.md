# Hostile-packet vectors

`cases.txt` lists packets and schemes that crafted input or a careless caller can send. Every package must answer each one the same way in kind: return an error value (never hang, never throw out of `unpack`), refuse the scheme at construction, or, for a `pack` case, refuse the row at pack time (an exception in most packages, an error return in C++ and Rust, with no bytes returned; `unpack` never throws, `pack` may). The file holds bytes and outcomes only. Each language writes the scheme by hand from `README.md` at the repository root (ADR-001: no shared walker, no generated schemes).

## Format of `cases.txt`

- UTF-8, LF line endings. Lines starting with `#` and blank lines are ignored.
- Data line: four fields separated by spaces or tabs: `id stage expected hex`.
  - `id`: `[a-z0-9_]+`, unique. Every id has a `## <id>` section below.
  - `stage`: `unpack` (build the scheme, unpack `hex`), `construct` (building the scheme must fail), `limit` (build the scheme with the limits the section gives, unpack `hex`) or `pack` (build the scheme and pack the row the section gives).
  - `expected`: outcome terms joined by `|`; any listed term is accepted, the first is preferred. A `pack` case has exactly one term: `bytes` or `pack_error`.
  - `hex`: lowercase, even length, starting with `01` for `unpack`, `limit` and a `pack` case that expects `bytes` (the packet that must come out); `-` for `construct` and for a `pack` case that expects `pack_error`.
- A `limit` case is a small packet that a scheme with a low round limit refuses. The file holds bytes and outcomes only, so the limit is not in it: the `## <id>` section names it and each package writes it by hand with its own call (`WithLimits`, `withLimits`, `with_limits`). A literal packet over the default limit (65,535 rounds, about 1 MiB) cannot live in the file; each package's own default-limit tests cover it. C#, TypeScript, Java, Rust and Python run `limit` cases (Python since loop 16). C++ unpacks into fixed arrays, so it has no round limit and its replay skips the stage.
- A `pack` case states its scheme and row in its section, not in the file, and the outcome is the packet `bytes` or `pack_error`: pack throws or returns an error and returns no bytes. One term covers every refusal (out of range, missing, wrong length); the error type and message are not asserted, each package's own tests do that. Each pack section has `Scheme`, `Row`, `Run by` and `Not run by` lines. Some packages cannot write a row (a typed row has a static type, so an out-of-range integer cannot be put in it). `Run by` lists the packages whose vector test packs the row and asserts the outcome, `Not run by` the packages whose test reports the case skipped, with the reason for each. Together the two lists name each of the six packages exactly once; `Not run by: none` is written when all six run the case. The check counts package names in the two lists, so a reason must not name another package (write "the typed row", not "like Rust"). A package never skips a case silently: a package in `Run by` that cannot run it fails.
- `check-cases.sh` checks all of this and that every id has a section here. `cases.test.sh` proves the check passes on the committed file and fails on corrupted copies. Both run in the `scaffold` job of `.github/workflows/test.yml`.

## Notation

- Every scheme has type number `1`, so every packet starts with `01`.
- Field order ids follow the README rule ("Field numbers are the order in the scheme"). A group's anchor equals the next value id and is not written. Ids continue through `flags`, `when`, `repeat` and `times` children. Only list and dict elements restart at 0.
- Wire rules: little-endian integers; `utf8` = `u16` length + bytes; `list` and `dict` = `u16` count; `sized`, `bits` and `times` take their count from an earlier integer field; `flags` = one `u8`, bit 0 = first child.
- Outcome terms:
  - `short_packet`, `trailing_bytes`, `bad_value`, `too_many`, `type_mismatch`: unpack returns that error value, with no exception and no row.
  - `scheme_error`: construction fails (an exception in C#, Java, TypeScript, Python and Rust; a compile error or `SchemeInvalid` in C++).
  - `bytes` and `pack_error`: the two `pack` outcomes. `bytes` means pack returns exactly the packet in `hex`; `pack_error` means pack throws (C#, Java, TypeScript, Python) or returns an error (Rust `PackError`, C++ `BadValue`) and returns no bytes.
- A `limit` case returns an error value whose kind is `too_many` or `bad_value`, with `needed` 0 and `left` 1: the limit refuses a round when it would start, before the round's bytes are read, so a short read of a field (`needed` above 0) does not satisfy it. Packages that have no `too_many` or `bad_value` type yet return their interim bad-value error (a short-packet value with `needed` 0). The field label in that error differs by package and is not asserted.
- Until the error-kind decision (C15) is taken, a package without a type for a kind passes the case with any non-ok unpack result that is not an exception, and names the kind it returned in the test name or message.
- Every `unpack` case returns within 1 second on CI hardware. A hang is a failure; each package test supplies its own time guard.

**Hex provenance.** The scan files describe each probe's scheme and result but did not record its exact bytes, apart from the C# and Java counts. Every hex value was derived from the wire rules and was not replayed against every package. A package task replays its cases on the current code first, checks that the documented failure reproduces, and corrects the file here, with the reason, if a value does not.

**Decision (2026-10-05).** The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` or a flag byte. Anywhere else is a scheme construction error. An empty group that could never set its bit (no member and no fields) is a construction error everywhere, inside `flags` too (decision 2026-10-05, loop 12).

**New in loop 21 (AZ-2394).** Fifteen cases at the end of the file, from the loop 21 reference (`_docs/03_implementation/reference_loop21_slots.md`, TypeScript): `pack_round_slots_at_limit`, `pack_round_slots_over_limit`, `pack_round_slots_flags_at_limit`, `pack_round_slots_flags_over_limit` (AZ-2381, AZ-2382), `pack_flags_short_list`, `pack_flags_short_list_filled` (AZ-2383), `pack_split_times_absent_body` (AZ-2384), `pack_late_when_in_bit_body` (AZ-2385), `pack_count_one_clear_when` (AZ-2386), `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when` (AZ-2387), and the `construct` cases `construct_empty_times_body`, `construct_empty_repeat_body`, `construct_empty_round_body_list_element` (AZ-2390). The 40 older cases are unchanged.

**New in loop 22 (AZ-2417).** Ten cases at the end of the file, from the loop 22 reference (`_docs/03_implementation/reference_loop22.md`, TypeScript): `pack_novalue_count_clear_when_bits`, `pack_novalue_count_clear_when_packed`, `pack_novalue_count_clear_when_sized` (AZ-2410), `pack_repeat_unequal_lists_lone`, `pack_repeat_unequal_lists_when` (AZ-2413), `pack_times_short_list_flags` (AZ-2414), `pack_element_times_over_bytes_budget` (AZ-2415), and the `construct` cases `construct_empty_when_times_body`, `construct_empty_when_repeat_body`, `construct_empty_nested_when_body` (AZ-2416). The 55 older cases are unchanged except the texts that carry the default `maxSlots`, which AZ-2415 lowered from 4,194,304 to 1,048,576: the Limit lines of `repeat_rounds_over_limit` and `times_rounds_over_limit`, and the Expected lines of `pack_slots_over_limit` (refused at round 16,132 with 1,048,580 slots) and `pack_element_times_over_budget` (now refused by the slots limit; its bytes route is the new `pack_element_times_over_bytes_budget`). AZ-2412 (Rust refuses per-name `repeat` lists given without round groups) has no case: a case has one outcome and the five other packages pack those lists (`01 01 05 02 06` for `n = [1, 2]`, `x = [5, 6]`), so the Rust refusal is pinned in the Rust package tests only. The three `construct_empty_*when*` cases name the `when` source outside the round, so a package with a scope rule (Rust, Python, Java, C#, and C++ by its source check) refuses them by that rule before it looks at the empty body; the case still asserts `scheme_error` only, and each package pins the empty-body rule itself in its own tests (C++ reaches it with a source-less `eq(-1, ...)`).

## zero_progress_repeat_bool

- Scheme: id0 `repeat` anchor 0 { id0 `bool on` }.
- Packet `01 ff`: type `01`; `ff` is left over. The body is a zero-width bool, so a round reads 0 bytes and the repeat never ends.
- Expected: `trailing_bytes` (the round adds nothing and the byte left is trailing), or `scheme_error` once a package refuses a bool outside flags.
- Source: C# probe 10 and Java probe 8 (infinite loop).

## zero_progress_repeat_when

- Scheme: id0 `u8 mode`; id1 `repeat` anchor 1 { id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 v` } }.
- Packet `01 00 ff`: type `01`; `mode` = `00`; `ff` is left over. The condition is false, so the body reads 0 bytes.
- Expected: `trailing_bytes`, or `scheme_error` for a package that rejects a `when` naming a field outside the repeat.
- Source: TypeScript and Python L8 (non-matching `when`), Rust LB1.

## negative_count

- Scheme: id0 `i8 n`; id1 `sized payload`, count = id0.
- Packet `01 ff 61`: type `01`; `n` = `ff` = -1; one byte `61` left.
- Expected: `bad_value` or `short_packet`. A negative count never reaches an allocation or a slice.
- Source: C# probe 9 and Java probe 7 (`i8` count -1). Unconfirmed: the probe's count consumer kind was not recorded; `sized` is chosen here.

## oversize_count

- Scheme: id0 `u32 n`; id1 `sized payload`, count = id0.
- Packet `01 ff ff ff ff 61`: type `01`; `n` = 4294967295; one byte left.
- Expected: `short_packet`. The count is larger than any signed 32-bit length.
- Source: C# probe 9 and Java probe 7 (`u32` count `0xFFFFFFFF`).

## oversize_count_times

- Scheme: id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `u8 v` }.
- Packet `01 ff ff ff ff 00`: type `01`; `n` = 4294967295; one byte left.
- Expected: `short_packet`. A package that checks capacity before reading may answer `too_many`; the file keeps `short_packet` until C15.
- Source: derived from C# and Java L9 (an `int` cast, pre-sized lists). Unconfirmed by a recorded probe.

## oversize_list_count

- Scheme: id0 `list xs` { element id0 `u8` }.
- Packet `01 ff ff`: type `01`; count = 65535; no bytes left.
- Expected: `short_packet`, or `too_many` for a fixed-capacity destination smaller than 65535 (C++ `Array<T, N>`).
- Source: derived. Unconfirmed: whether C++ checks capacity or bytes first.

## invalid_utf8

- Scheme: id0 `utf8 name`.
- Packet `01 02 00 c3 28`: type `01`; length `02 00` = 2; bytes `c3 28`, an invalid two-byte sequence.
- Expected: `bad_value` or `short_packet`.
- Source: TypeScript and Python L14 (`TypeError`, `UnicodeDecodeError`); Rust returns `Short` today. C++ borrows raw bytes and does not validate (open question).

## invalid_utf8_dict_key

- Scheme: id0 `dict m` { element id0 `u8` }.
- Packet `01 01 00 01 00 ff 00`: type `01`; count `01 00` = 1; key length `01 00` = 1; key byte `ff`; value `00`.
- Expected: `bad_value` or `short_packet`.
- Source: derived (Rust decodes dict keys). Unconfirmed for TypeScript and Python.

## count_behind_clear_flag

- Scheme: id0 `flags` anchor 0 { id0 `u8 n` }; id1 `sized payload`, count = id0.
- Packet `01 00`: type `01`; flag byte `00`, so `n` is absent and the count has no value.
- Expected: `bad_value` or `scheme_error`.
- Source: TypeScript and Python L14 (`RangeError`, `RuntimeError`). C++ returns `BadValue` today.

## count_behind_clear_flag_bits

- Scheme: as `count_behind_clear_flag`, with id1 `bits segs`, count = id0.
- Packet `01 00`: as above.
- Expected: `bad_value` or `scheme_error`.
- Source: TypeScript L14 (silently returns `[]` today).

## nine_flag_bits

- Scheme: id0 `flags` anchor 0 { id0 to id8: nine children `u8 f0` to `u8 f8` }.
- No packet: construction must fail. One flags byte holds 8 bits.
- Expected: `scheme_error`.
- Source: C# probe 3 (the 9th value is dropped), Rust LB2 (debug panic, release alias), TypeScript and Python L4.

## nine_flag_bits_split

- Scheme: id0 split-form `flag_byte`; nine `bit(...)` fields id1 to id9, each a `u8`. In packages whose flag byte takes no order id (C#, TypeScript, Python, Java, C++) the bits are id0 to id8.
- No packet: construction must fail.
- Expected: `scheme_error`.
- Source: Rust LB2 (`field/mod.rs:144`); Python already rejects it. In TypeScript, Java and (since AZ-2230) Python a `flag_byte` handle holds no bit, so the ninth `bit(...)` call builds and the scheme refuses it when it is built.

## when_names_later_field

- Scheme: id0 `u8 a`; id1 `when` anchor 1, `eq(2, 1)` { id1 `u8 b` }; id2 `u8 c`.
- No packet: the tested field must already have been read, so id2 is not allowed.
- Expected: `scheme_error`.
- Source: C# probe 11, Java probe 5 (README: "The tested field must already have been read").

## count_names_later_field

- Scheme: id0 `sized payload`, count = id1; id1 `u16 n`.
- No packet: construction must fail.
- Expected: `scheme_error`.
- Source: Java probe 6 (constructs, then throws at pack).

## when_names_outer_field_in_repeat

- Scheme: the scheme of `zero_progress_repeat_when`: the `when` inside the `repeat` names `mode`, a field outside it.
- No packet: construction must fail.
- Expected: `scheme_error`. C++, Rust (task 06), Java (task 20), C# (AZ-2087), TypeScript (AZ-2090) and Python (AZ-2113) refuse it at construction.
- Source: Rust LB1.

## bool_outside_flags

- Scheme: id0 `u8 a`; id1 `bool on`.
- No packet: a zero-width bool outside `flags` always reads as true and cannot round-trip.
- Expected: `scheme_error`.
- Source: C# probe 2, Java probe 9, C++ LB7. User decision 2026-10-05.

## empty_group_outside_flags

- Scheme: id0 `u8 a`; id1 `group` with no children.
- No packet: an empty group is a presence bit and is allowed only inside `flags` or a flag byte.
- Expected: `scheme_error`.
- Source: C++ LB7. User decision 2026-10-05.

## eq_bool_false

- Scheme: id0 `flags` anchor 0 { id0 `bool on` }; id1 `when` anchor 1, `eq(0, false)` { id1 `u8 v` }.
- No packet: a `false` bool leaves its bit clear and is absent on the wire, so a `when` on `eq(0, false)` could never match on unpack. `eq` on a bool or an empty group accepts only `true`; the same scheme with `eq(0, true)` builds and round-trips (`{on: true, v: 5}` packs `010105`).
- Expected: `scheme_error`. Rust has no bool value: its bool is an empty group, `false` is `U8(0)` and `true` is `eq(id, 1)`. C++ refuses the literal `eq(0, false)` at compile time (`cpp/tests/compile-fail/when_eq_bool_false.cpp`); its vector builds the scheme with `eq(0, 0)`, which `validate` refuses at run time.
- Source: loop 12 review findings; user decision 2026-10-05 (AZ-2126, built in loop 18).

## eq_out_of_range

- Scheme: id0 `u8 a`; id1 `when` anchor 1, `eq(0, 300)` { id1 `u8 v` }.
- No packet: 300 is outside the `u8` source (0 to 255), so the condition could never match. Construction must fail, before any pack or unpack.
- Expected: `scheme_error`. The same refusal covers a value that is not an integer (a string, NaN, a fraction) or a bool for an integer source in the packages whose language can write one (C#, TypeScript, Java, Python, Rust). C++ is covered for out-of-range integers only: its typed constants convert, so `eq(0, 1.5)` and `eq(0, true)` on a `u8` source still build (decision 2026-10-11, point 4). A whole-number float equal to an integer (`5.0`) is not part of this case: C# and TypeScript accept it, Java, Python and Rust refuse it (documented in the upgrade notes).
- Rust: the constant is `Value::U16(300)` against the `u8` field. C++: the literal fails to compile (`cpp/tests/compile-fail/when_eq_out_of_range.cpp`); its vector builds the scheme at run time with the constant 300 and expects `SchemeInvalid`.
- Source: loop 19, AZ-2338 (owner decision 11, 2026-10-11); review C5, T8.

## repeat_rounds_over_limit

- Scheme: id0 `repeat` anchor 0 { id0 `u8 v` }.
- Limit: `maxRounds` 3; `maxSlots` at its default (1,048,576).
- Packet `01 11 22 33 44`: type `01`; four one-byte rounds. The fourth round would be the fourth started, above the limit, so it is refused when it would start, with its byte `44` left.
- Expected: `too_many` or `bad_value`, with `needed` 0 and `left` 1. No handler call, no row. The label of the error is not asserted.
- Source: loop 15, AZ-2216 to AZ-2219 (round limits); the bytes were run against each package's real code.
- Run by: C# (`Scheme<T>.WithLimits(maxRounds: 3)`), TypeScript (`withLimits({ maxRounds: 3 })`), Java (`withLimits(3, Scheme.DEFAULT_MAX_SLOTS)`), Rust (`with_limits(3, DEFAULT_MAX_SLOTS)`), Python (`with_limits(max_rounds=3)`).
- Not run by: C++ (fixed `Array<T, N>` storage and `Error::TooMany`, so no round budget to set). Its replay skips the stage.

## times_rounds_over_limit

- Scheme: id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `u8 v` }.
- Limit: `maxRounds` 3; `maxSlots` at its default (1,048,576).
- Packet `01 04 11 22 33 44`: type `01`; `n` = 4; four one-byte rounds. The count 4 is above the limit but is not refused up front (the check is lazy, so `oversize_count_times` keeps its short read); round 4 is refused when it would start, with its byte `44` left.
- Expected: `too_many` or `bad_value`, with `needed` 0 and `left` 1. No handler call, no row. The label of the error is not asserted.
- Source: loop 15, AZ-2216 to AZ-2219; the bytes were run against each package's real code.
- Run by: C#, TypeScript, Java, Rust, Python (calls as in `repeat_rounds_over_limit`).
- Not run by: C++, for the reason given there.

## pack_out_of_range_integer

- Scheme: id0 `u8 a`.
- Row: `a = 300`.
- Expected: `pack_error`. 300 does not fit in a `u8`; pack refuses the row and does not wrap it to `2c`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form, `Value::U16(300)` for the `u8` field).
- Not run by: C++ (a typed row binds a `std::uint8_t` member, so 300 cannot be written).
- Source: AZ-2084 (TypeScript range check) and the loud-pack tickets of loop 13; probed in every listed package in loop 18.

## pack_missing_required_value

- Scheme: id0 `u8 a`; id1 `u8 b`.
- Row: `a = 1`, no `b`.
- Expected: `pack_error`. A walked field with no value is an error, never a shorter packet.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (the member of `b` is an `Opt<std::uint8_t>` left unset; pack returns `BadValue`).
- Not run by: none.
- Source: AZ-2088 (C# loud missing value); probed in every package in loop 18.

## pack_times_list_too_long

- Scheme: id0 `u8 a`; id1 `times` anchor 1, count = id0 { id1 `u8 x` }.
- Row: `a = 2`, `x = [1, 2, 3]`.
- Expected: `pack_error`. A list longer than the count is refused, never cut to two entries.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of three items beside `a = 2`; pack returns `BadValue`).
- Not run by: none.
- Source: AZ-2088 (C#), AZ-2185 (TypeScript), AZ-2186 (Python), AZ-2187 (Java); Rust refuses it with a type error; probed in every package in loop 18.

## pack_times_list_too_short

- Scheme: as `pack_times_list_too_long`.
- Row: `a = 2`, `x = [1]`.
- Expected: `pack_error`. A list shorter than the count is refused, never padded or cut to one round.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of one item beside `a = 2`; pack returns `BadValue`).
- Not run by: none.
- Source: AZ-2088 (C#); probed in every package in loop 18.

## pack_aligned_round_row

- Scheme: id0 `repeat` anchor 0 { id0 `flags` anchor 0 { id0 `bool on`, id1 `u8 n` } }.
- Row: `on = [true, false, true]`, `n = [1, 2, 3]` (one entry per round). In Rust, whose bool is an empty group, three round rows: `on` set in rounds 0 and 2, absent in round 1.
- Packet `01 0301 0202 0303`: type `01`; per round one flags byte (bit 0 `on`, bit 1 `n` present) then `n`. The `false` leaves its bit clear and `n` still sits in its own round.
- Expected: `bytes` `01030102020303`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of three rounds with `Opt<bool> on` and `Opt<std::uint8_t> n`).
- Not run by: none.
- Source: AZ-2179 (the `roundflags` ring) and AZ-2134 (Python aligned rows, loop 16); the bytes were run against each package's real code in loop 18.

## pack_times_count_over_limit

- Scheme: id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `u8 x` }.
- Row: `n = 65536`, `x = 7` (one scalar, not a list).
- Expected: `pack_error`. The count is one above the default `maxRounds` (65,535). Pack refuses it before it writes any round, with no allocation proportional to the count (a count of 4,000,000,000 behaves the same). A scheme built with a higher `maxRounds` packs that many rounds.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (it has no round limit on pack: the rounds live in a fixed `Array` of at most 65,535 items, and a count of 65,536 is refused only as a count that differs from the array length, which `pack_times_list_too_long` already covers).
- Source: loop 19, AZ-2329 (owner decision 1, security F21, review R1).

## pack_times_zero_with_values

- Scheme: as `pack_times_list_too_long`.
- Row: `a = 0`, `x = [5]`.
- Expected: `pack_error`. A count of 0 with a list that holds a value is refused, never packed as zero rounds. A lone scalar with count 0 is not part of this case: all six packages pack `0100` for it (documented).
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of one item beside `a = 0`; pack returns `BadValue`).
- Not run by: none.
- Source: loop 19, AZ-2335 (owner decision 7).

## pack_split_when_source_after_byte

- Scheme: split-form `flag_byte` (id0 in Rust, no order id elsewhere); `u8 mode` written after the byte; bit 0 { `when` `eq(mode, 1)` { `u8 speed` } }.
- Row: `mode = 1`, `speed = 7`.
- Expected: `pack_error`. The byte is written before `mode`, so its bit 0 is clear although the condition holds and the body is given; writing the body anyway would make a packet whose bit says "absent". Pack refuses it, naming `speed`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row with `speed` set and `mode` 1).
- Not run by: none.
- Source: loop 19, AZ-2331 AC-1 (owner decision 3).

## pack_split_times_count_after_byte

- Scheme: split-form `flag_byte`; `u8 n` written after the byte; bit 0 { `times` count = `n` { `u8 pt` } }.
- Row: `n = 2`, `pt = [5, 6]`.
- Expected: `pack_error`. Same reason as `pack_split_when_source_after_byte`, for a count: the bit was decided before `n` was written.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of two beside `n = 2`).
- Not run by: none.
- Source: loop 19, AZ-2331 AC-1.

## pack_split_times_count_skipped

- Scheme: `u8 sel`; split-form `flag_byte`; `when` `eq(sel, 1)` { `u8 n` }; bit 0 { `times` count = `n` { `u8 pt` } }.
- Row: `sel = 0`, `pt = [5]`.
- Expected: `pack_error`. The `when` is false, so `n` is never written; rounds were given for a count that does not exist, and packing would drop them silently. Pack refuses it, naming `pt`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of one beside `sel = 0` and no `n`).
- Not run by: none.
- Source: loop 19, AZ-2331 AC-2.

## pack_lone_bytes_in_round

- Scheme: id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `bytes(2) d` }.
- Row: `n = 2`, `d` = one 2-byte buffer `0102` (not a list of buffers).
- Expected: `pack_error`. A byte buffer given once for a round name is not broadcast to every round (it used to be in four packages); a list with one buffer per round (`[0102, 0304]` with `n = 2`) is the form that packs, to `010201020304`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form, `Value::Bytes`).
- Not run by: C++ (a typed row holds an `Array` of `Array`, so a lone buffer cannot be written).
- Source: loop 19, AZ-2332 (owner decision 4, assessment U1).

## pack_split_false_condition_silent

- Scheme: id0 `u8 mode`; split-form `flag_byte`; bit 0 { `when` `eq(mode, 1)` { `u8 speed` } }; bit 1 { `u16 heading` }.
- Row: `mode = 0`, `speed = 7`, `heading = 90`.
- Packet `01 00 02 5a00`: type `01`; `mode` 0; flag byte `02` (bit 1 only); `heading` `5a00`.
- Expected: `bytes` `0100025a00`. The condition is false, so `speed` is not written and the bit stays clear. This is not an error: giving every member of a row while a condition decides which are written is normal use (decision 2026-10-11, AZ-2331 AC-3).
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row with `speed` set).
- Not run by: none.
- Source: loop 18 reference row W-split-false-body-given; loop 19, AZ-2331 AC-3 (owner decision A, 2026-10-11).

## pack_lone_utf8_under_times_over_budget

- Scheme: id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `utf8 s` }.
- Row: `n = 65535`, `s` = 65,535 times `a` (one string, not a list).
- Expected: `pack_error`. The count is at the default `maxRounds` (65,535), so the count check passes; the rounds are 65,537 bytes each (`u16` length and text), so the packet would pass the default `maxBytes` (16,777,216) at round 256. Pack refuses it at that round, naming `s`, and never builds the 4 GiB packet.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (pack writes into a caller buffer of fixed size and rounds live in a fixed `Array`, so there is no output budget to pass).
- Source: loop 20, AZ-2354 (reference row 1), AZ-2367.

## pack_element_times_over_budget

- Scheme: id0 `list items` of an element `group` { id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `u64 k` } }.
- Row: 40 items, each `n = 65535`, `k = 5` (one scalar per item).
- Expected: `pack_error`. Since loop 22 (AZ-2415) the slots limit refuses it, not the bytes budget it was written to reach: the budget runs across the list elements as one counter, 16 items of 65,535 one-slot rounds are 1,048,560 slots, and round 17 of item 17 would hold 1,048,577 slots, above the default `maxSlots` (1,048,576). Pack refuses it there, naming `k` (`k: the rounds would hold 1048577 slots, above the limit of 1048576 slots` in TypeScript), and returns no bytes. The bytes route this case used to take (each item is about 524,284 bytes; the packet passed `maxBytes` in item 33) moved to `pack_element_times_over_bytes_budget`.
- Run by: TypeScript, Python, Java, C# (dictionary rows).
- Not run by: Rust (a list element cannot hold a `times`), C++ (a fixed array of rounds and a caller buffer, as in `pack_lone_utf8_under_times_over_budget`).
- Source: loop 20, AZ-2354 (reference row 2), AZ-2367; slots text updated in loop 22, AZ-2415, AZ-2417.

## pack_slots_over_limit

- Scheme: id0 `u32 n`; id1 `times` anchor 1, count = id0 { 65 `u8` members, ids 1 to 65 }.
- Row: `n = 65535`, each member `1` (one scalar per member).
- Expected: `pack_error`. 65,535 rounds of 65 slots are 4,259,775 slots, above the default `maxSlots` (1,048,576, lowered from 4,194,304 in loop 22, AZ-2415); the bytes (4,259,780) stay far under `maxBytes`, so the slot count refuses the row, at round 16,132 (1,048,580 slots: `m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots` in TypeScript), before that round's first byte. The width has no group, so it is 65 in every package.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a fixed array of rounds and a caller buffer, as in `pack_lone_utf8_under_times_over_budget`).
- Source: loop 20, AZ-2354 (reference row 14), AZ-2367; numbers updated in loop 22, AZ-2415, AZ-2417.

## pack_repeat_over_limit

- Scheme: id0 `repeat` anchor 0 { id0 `u8 k` }.
- Row: `k` = a list of 65,536 entries (each `7`).
- Expected: `pack_error`. The list is one above the default `maxRounds` (65,535); pack refuses it before the first round, as unpack refuses the same packet.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (the rounds live in a fixed `Array` of at most 65,535 items).
- Source: loop 20, AZ-2355 (reference row 1), AZ-2367.

## pack_split_count_zero_after_byte_list

- Scheme: split-form `flag_byte`; `u8 n` written after the byte; bit 0 { `times` count = `n` { `u8 pt` } }.
- Row: `n = 0`, `pt = [5, 6]`.
- Expected: `pack_error`. The count is 0 but the list holds values, so pack refuses it, as `pack_times_zero_with_values` does for a scheme without a flag byte. The bit was decided before `n` was written and the values would be dropped silently.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of two beside `n = 0`).
- Not run by: none.
- Source: loop 20, AZ-2356 (owner decision 3), AZ-2367.

## pack_split_count_zero_after_byte_scalar

- Scheme: as `pack_split_count_zero_after_byte_list`.
- Row: `n = 0`, `pt = 5` (one scalar, not a list).
- Packet `01 00 00`: type `01`; flag byte `00` (bit 0 clear); `n` = `00`. A lone scalar with count 0 packs zero rounds, so the bit stays clear and nothing follows `n`.
- Expected: `bytes` `010000`. Not an error: a lone value for a count of 0 is the same as `pack_times_zero_with_values` leaves it (a scalar, not a list that holds a value).
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a typed row holds an `Array`, so a lone scalar cannot be written).
- Source: loop 20, AZ-2356 (owner decision 3), AZ-2367.

## pack_flags_skipped_count_with_values

- Scheme: id0 `flags` anchor 0 { id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `u8 pt` } }.
- Row: `n` not given (its flag bit stays clear), `pt = [5, 6]`.
- Expected: `pack_error`. The count is skipped, so no round count exists; pack refuses the rounds that were given, naming `pt`, and never drops them silently.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (an `Array` of two with `n` unset).
- Not run by: none.
- Source: loop 20, AZ-2360, AZ-2367.

## pack_round_slots_at_limit

- Scheme: id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `u8 a` }; id2 `repeat` anchor 2 { id2 `u8 b` }. Each round of either container holds one name, so one round charges 1 slot.
- Limit: `maxSlots` 3; `maxRounds` at its default (65,535); `maxBytes` at its default.
- Row: `n = 1`, `a = [1]`, `b = [2, 3]`. In Rust, whose `repeat` rounds are groups: `__repeat__` holds two round rows (`b = 2`, `b = 3`).
- Packet `01 01 01 02 03`: type `01`; `n` = 1; the one `times` round `01`; the two `repeat` rounds `02` and `03`.
- Expected: `bytes` `0101010203`. The `times` charges 1 slot and the `repeat` 2: 3 slots, exactly the limit, so it packs. One counter runs through the whole pack call and is shared by every `repeat` and `times`; a round is charged by the number of distinct names it can hold, before its first byte.
- Run by: TypeScript (`new Scheme(..., { maxSlots: 3 })`), Python (`with_limits(max_slots=3)`), Java (`withLimits(Scheme.DEFAULT_MAX_ROUNDS, 3)`), C# (`WithLimits(65535, 3)`), Rust (`with_limits(DEFAULT_MAX_ROUNDS, 3)`).
- Not run by: C++ (fixed `Array` rounds and a caller buffer, so no round or slot budget to set).
- Source: loop 21, AZ-2382 (reference row 13), AZ-2394.

## pack_round_slots_over_limit

- Scheme: as `pack_round_slots_at_limit`.
- Limit: as `pack_round_slots_at_limit` (`maxSlots` 3).
- Row: `n = 1`, `a = [1]`, `b = [2, 3, 4]` (a third `repeat` round).
- Expected: `pack_error`. The three rounds would hold 4 slots, one above the limit; pack refuses the third `repeat` round before its first byte and returns no bytes.
- Run by: TypeScript, Python, Java, C#, Rust (calls as in `pack_round_slots_at_limit`, with three round rows).
- Not run by: C++ (as in `pack_round_slots_at_limit`).
- Source: loop 21, AZ-2382 (reference row 14), AZ-2394.

## pack_round_slots_flags_at_limit

- Scheme: id0 `repeat` anchor 0 { id0 `flags` anchor 0 { id0 `bool on`, id1 `u8 v` } }. The width of a round is 2: the names `on` and `v`; the `flags` itself and its combined byte are no slot. In Rust, whose bool is an empty group, `on` is an empty group named `on`.
- Limit: `maxSlots` 4; the other limits at their defaults.
- Row: `on = [true, true]`, `v = [5, 6]`. In Rust, two round rows with `on` set and `v` 5, then 6.
- Packet `01 0305 0306`: type `01`; per round one flags byte `03` (both bits set) then `v`.
- Expected: `bytes` `0103050306`. Two rounds of width 2 are 4 slots, exactly the limit.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (round rows).
- Not run by: C++ (as in `pack_round_slots_at_limit`).
- Source: loop 21, AZ-2381 and AZ-2382 (reference row 3), AZ-2394.

## pack_round_slots_flags_over_limit

- Scheme: as `pack_round_slots_flags_at_limit`.
- Limit: `maxSlots` 4.
- Row: `on = [true, true, true]`, `v = [5, 6, 7]` (a third round; Rust gives three round rows).
- Expected: `pack_error`. The third round would hold 6 slots, above the limit of 4; pack refuses it before its first byte. A package that also charged the `flags` name or its byte (width 3 or 4) would refuse the two-round row of `pack_round_slots_flags_at_limit`; a package that charged only `v` would accept this one.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (round rows).
- Not run by: C++ (as in `pack_round_slots_at_limit`).
- Source: loop 21, AZ-2381 and AZ-2382 (reference row 3), AZ-2394.

## pack_flags_short_list

- Scheme: id0 `repeat` anchor 0 { id0 `u8 w`; id1 `flags` anchor 1 { id1 `u8 v` } }.
- Row: `w = [1, 2]`, `v = [5]` (one entry for two rounds).
- Expected: `pack_error`. A non-empty list under a member that a flag bit can leave absent must give one entry per round (an absent entry where the member is absent); a list shorter than the rounds is refused before any round, naming `v`, and the old packet `010101050200` is no longer produced. The `repeat` count comes from the longest list; `times` keeps accepting a short list under `flags`, and that is not part of this case.
- Run by: TypeScript, Python, Java, C# (dictionary rows).
- Not run by: Rust (a `repeat` takes its rounds as groups, one row per round, so there is no list to be too short), C++ (a fixed `Array` of round items whose length is the round count, so a short list cannot be written).
- Source: loop 21, AZ-2383 (reference row 27), AZ-2394.

## pack_flags_short_list_filled

- Scheme: as `pack_flags_short_list`.
- Row: `w = [1, 2]`, `v = [5, absent]` (a full list whose second entry is the language's absent value: `undefined` or `null`, `None`, `null`; in Rust, round 2 has no `v`; in C++ an `Array` of two rounds whose second `Opt<std::uint8_t> v` is unset).
- Packet `01 0101 05 0200`: type `01`; round 1: `w` = 1, flags byte `01`, `v` = 5; round 2: `w` = 2, flags byte `00`.
- Expected: `bytes` `010101050200`. The same bytes the short list used to produce, now written with one entry per round.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (round rows), C++ (a typed row with the `Opt` unset in round 2).
- Not run by: none.
- Source: loop 21, AZ-2383 (reference row 29), AZ-2394.

## pack_split_times_absent_body

- Scheme: split-form `flag_byte` (id0 in Rust, no order id elsewhere), written first; `u8 n`; bit 0 { `times` count = `n` { `u8 pt` } }; bit 1 { `u16 heading` }.
- Row: `n = 2`, `heading = 90`, no `pt`. A row that also gives `pt = []` packs the same bytes.
- Packet `01 02 02 5a00`: type `01`; flag byte `02` (bit 1 only); `n` = 2; `heading` `5a00`.
- Expected: `bytes` `0102025a00`. The count is above 0 and the `times` has no rounds in the row, so its bit stays clear and nothing is dropped. The count `n` is written inside the packet whatever the bit says.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (AZ-2384 excludes it, loop 21 finding): its row holds the rounds as an `Array`; a count of 2 with an `Array` of 0 items is a count mismatch, not an absent body, and the late rule (AZ-2385) refuses it.
- Source: loop 21, AZ-2384 (reference rows 40 and 41), AZ-2394.

## pack_late_when_in_bit_body

- Scheme: split-form `flag_byte`, written first; `u8 mode` after the byte; bit 0 { a group (anonymous where the package names none) { `u8 d`; `when` `eq(mode, 1)` { `u8 a` }; `when` `eq(mode, 2)` { `u8 b` } } }. The `when` source `mode` is written after the flag byte, so the bit's `when`s are late.
- Row: `mode = 1`, `d = 5`, `a = 9`, no `b`.
- Packet `01 01 01 05 09`: type `01`; flag byte `01` (bit 0 set by `d`); `mode` = 1; `d` = 5; `a` = 9.
- Expected: `bytes` `0101010509`. Another member of the bit (`d`) is given, so the bit is set and the late `when` whose condition holds writes its body. (A row that gives only the late `a`, with no `d`, stays `pack_error` as in `pack_split_when_source_after_byte`, and is not part of this case.)
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row with `d` and `a` set).
- Not run by: none.
- Source: loop 21, AZ-2385 (the C++ change; the TypeScript probe of loop 21 gives the same bytes), AZ-2394.

## pack_count_one_clear_when

- Scheme: id0 `u8 mode`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 c` }; split-form `flag_byte` (id2 in Rust); bit 0 { `times` count = `c` { `u8 pt` } }; bit 1 { `u16 heading` }.
- Row: `mode = 0`, `c = 1`, `heading = 90`, no `pt`.
- Expected: `pack_error`. The `when` is clear, so `c` is never written and the count is a value the packet cannot hold: the `times` would read a round the packet has no count for. Pack refuses it, naming `pt`. A count of 0 or a row without `c` packs `0100025a00` (not part of this case).
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row with `c` set to 1 and `mode` 0).
- Not run by: none.
- Source: loop 21, AZ-2386 (reference row 44), AZ-2394.

## pack_bits_count_clear_when

- Scheme: id0 `u8 mode`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 c` }; id2 `bits v`, count = id1.
- Row: `mode = 0`, `c = 3`, `v = [1, 0, 1]`.
- Expected: `pack_error`. The `when` is clear, so `c` is not written and `v` has no count on the wire; pack refuses the row, naming `v`, and never writes the bits.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row; the bits member is given three values).
- Not run by: none.
- Source: loop 21, AZ-2387 (reference row 53), AZ-2394.

## pack_packed_count_clear_when

- Scheme: as `pack_bits_count_clear_when`, with id2 `packed v` (width 1, bias 0), count = id1 in place of `bits`.
- Row: `mode = 0`, `c = 3`, `v = [1, 0, 1]`.
- Expected: `pack_error`, for the reason given in `pack_bits_count_clear_when`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row; the packed member is given three values).
- Not run by: none.
- Source: loop 21, AZ-2387 (reference row 53), AZ-2394.

## pack_sized_count_clear_when

- Scheme: as `pack_bits_count_clear_when`, with id2 `sized v`, count = id1 in place of `bits`.
- Row: `mode = 0`, `c = 3`, `v` = the three bytes `010203`.
- Expected: `pack_error`, for the reason given in `pack_bits_count_clear_when`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form), C++ (typed row; the sized member holds three bytes).
- Not run by: none.
- Source: loop 21, AZ-2387 (reference row 53), AZ-2394.

## construct_empty_times_body

- Scheme: id0 `u8 n`; id1 `times` anchor 1, count = id0 { } with no child.
- No packet: a round body must hold at least one member (a value field, a zero-width `bytes`, a list, a dict, a flag byte or bit, a `flags`); a `times` with none would charge no slot and write no byte, so a count of 65,535 rounds would cost nothing to the budget. Construction must fail, before any pack or unpack.
- Expected: `scheme_error` (C++: `Error::SchemeInvalid` at construction). A body made only of empty `when`s or empty groups holds no member and is refused the same way; a body with a zero-width `bytes`, a flag byte or a member-less `flags` still builds (the `zero_progress_repeat_*` vectors rely on it).
- Source: loop 21, AZ-2390 (reference rows 16 and 17), AZ-2394.

## construct_empty_repeat_body

- Scheme: id0 `repeat` anchor 0 { } with no child.
- No packet: as `construct_empty_times_body`.
- Expected: `scheme_error` (C++: `Error::SchemeInvalid` at construction).
- Source: loop 21, AZ-2390 (reference row 15), AZ-2394.

## construct_empty_round_body_list_element

- Scheme: id0 `list items` of an element `group` { id0 `u32 n`; id1 `times` anchor 1, count = id0 { } with no child }. This is the shape that asked a package to pack a list of items each holding a count of 65,535 empty rounds.
- No packet: construction must fail in well under a second, before any item is built.
- Expected: `scheme_error`. Packages whose list element cannot hold a `times` (Rust, C++ with its fixed arrays) have no spelling of this shape; their test for the plain empty `times` of `construct_empty_times_body` covers the same refusal, and their loader names this id as skipped for that reason.
- Source: loop 21, AZ-2390 (reference row 20, the F33 request shape), AZ-2394.

## pack_novalue_count_clear_when_bits

- Scheme: id0 `u8 mode`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 c` }; split-form `flag_byte` (id2 in Rust); bit 0 { id2 `bits v`, count = id1 }.
- Row: `mode = 0`, `c = 3`, no `v`.
- Expected: `pack_error`. The `when` is clear, so `c` is never written, and the row holds a count above 0 for a member that has no value: the member would read nothing from a count the packet cannot hold. Pack refuses it, naming `v` and the count, and never writes the clear bit (the bits member, as in `pack_bits_count_clear_when`, but with no value given). A count of 0, a row without `c`, or a holding `when` (`mode = 1`) packs the clear bit (`010000`, `010000`, `01010300`) and is not part of this case; a row that gives `v` stays `pack_error` as in `pack_bits_count_clear_when`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a typed row has no "no value" for a bits member: it always holds the member, so the row is refused anyway as a count that differs from the member's length).
- Source: loop 22, AZ-2410 (reference row 56), AZ-2417.

## pack_novalue_count_clear_when_packed

- Scheme: id0 `u8 mode`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 c` }; split-form `flag_byte` (id2 in Rust); bit 0 { id2 `packed v` (width 1, bias 0), count = id1 }.
- Row: `mode = 0`, `c = 3`, no `v`.
- Expected: `pack_error`. The `when` is clear, so `c` is never written, and the row holds a count above 0 for a member that has no value: the member would read nothing from a count the packet cannot hold. Pack refuses it, naming `v` and the count, and never writes the clear bit (as above). A count of 0, a row without `c`, or a holding `when` (`mode = 1`) packs the clear bit (`010000`, `010000`, `01010300`) and is not part of this case; a row that gives `v` stays `pack_error` as in `pack_packed_count_clear_when`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a typed row has no "no value" for a packed member: it always holds the member, so the row is refused anyway as a count that differs from the member's length).
- Source: loop 22, AZ-2410 (reference row 56), AZ-2417.

## pack_novalue_count_clear_when_sized

- Scheme: id0 `u8 mode`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 c` }; split-form `flag_byte` (id2 in Rust); bit 0 { id2 `sized v`, count = id1 }.
- Row: `mode = 0`, `c = 3`, no `v`.
- Expected: `pack_error`. The `when` is clear, so `c` is never written, and the row holds a count above 0 for a member that has no value: the member would read nothing from a count the packet cannot hold. Pack refuses it, naming `v` and the count, and never writes the clear bit (as above). A count of 0, a row without `c`, or a holding `when` (`mode = 1`) packs the clear bit (`010000`, `010000`, `01010300`) and is not part of this case; a row that gives `v` stays `pack_error` as in `pack_sized_count_clear_when`.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a typed row has no "no value" for a sized member: it always holds the member, so the row is refused anyway as a count that differs from the member's length).
- Source: loop 22, AZ-2410 (reference row 56), AZ-2417.

## pack_repeat_unequal_lists_lone

- Scheme: id0 `repeat` anchor 0 { id0 `u8 a`; id1 `u8 b` }.
- Row: `a = [1, 2]`, `b = 7` (a list beside one scalar).
- Packet `01 01 07 02 07`: type `01`; round 1: `a` = 1, `b` = 7; round 2: `a` = 2, `b` = 7.
- Expected: `bytes` `0101070207`. The round count is the longest list (2); a lone value is given to every round.
- Run by: TypeScript, Python, Java, C# (dictionary rows).
- Not run by: Rust (a `repeat` takes its rounds as groups only, one row per round, so per-name lists are refused), C++ (a typed row holds an `Array` of round items, so a lone value for one round member cannot be written).
- Source: loop 22, AZ-2413 (reference row R2a), AZ-2417.

## pack_repeat_unequal_lists_when

- Scheme: id0 `repeat` anchor 0 { id0 `u8 k`; id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 v` } }.
- Row: `k = [1, 2]`, `v = [9]` (the `when` holds in round 1 only, so the shorter list is enough).
- Packet `01 01 09 02`: type `01`; round 1: `k` = 1, the `when` holds, `v` = 9; round 2: `k` = 2, the `when` is clear and reads no `v`.
- Expected: `bytes` `01010902`. A list for a member that only some rounds reach may be shorter than the round count; a round whose `when` is clear never reads it.
- Run by: TypeScript, Python, Java, C# (dictionary rows).
- Not run by: Rust (a `repeat` takes its rounds as groups only, one row per round, so per-name lists are refused), C++ (a typed row holds an `Array` of round items, so a shorter list for one round member cannot be written).
- Source: loop 22, AZ-2413 (reference row R3a), AZ-2417.

## pack_times_short_list_flags

- Scheme: id0 `u8 c`; id1 `times` anchor 1, count = id0 { id1 `flags` anchor 1 { id1 `u8 v` } }.
- Row: `c = 2`, `v = [5]` (one entry for two rounds).
- Packet `01 02 01 05 00`: type `01`; `c` = 2; round 1: flags byte `01`, `v` = 5; round 2: flags byte `00` (the list ran out, so the bit stays clear).
- Expected: `bytes` `0102010500`. A `times` accepts a short list under a `flags`; the older `repeat` rule of `pack_flags_short_list` (one entry per round) does not apply to it.
- Run by: TypeScript, Python, Java, C# (dictionary rows), Rust (map form).
- Not run by: C++ (a typed row holds an `Array` with one item per round, so a list shorter than the count cannot be written).
- Source: loop 22, AZ-2414 (reference row A1), AZ-2417.

## pack_element_times_over_bytes_budget

- Scheme: id0 `list items` of an element `group` { id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `utf8 s` } }.
- Row: 16 items, each `n = 65535`, `s` = 16 times `a` (one string per item, not a list).
- Expected: `pack_error`. A round is 18 bytes (`u16` length and 16 characters), an item about 1,179,634 bytes, so the packet would be 18,874,147 bytes, above the default `maxBytes` (16,777,216): pack refuses it in item 15 at round 14,575 (16,777,233 bytes), naming `s`. The slots stay under the limit (16 x 65,535 = 1,048,560, below the default `maxSlots` of 1,048,576), so the bytes budget refuses it, not the slots limit; this is the route `pack_element_times_over_budget` took before AZ-2415. A scheme built with `maxBytes` 33,554,432 packs the row to 18,874,147 bytes and unpacks it.
- Run by: TypeScript, Python, Java, C# (dictionary rows).
- Not run by: Rust (a list element cannot hold a `times`), C++ (a fixed array of rounds and a caller buffer, as in `pack_lone_utf8_under_times_over_budget`).
- Source: loop 22, AZ-2415 (reference section 2), AZ-2417.

## construct_empty_when_times_body

- Scheme: id0 `u8 mode`; id1 `u8 c`; id2 `times` anchor 2, count = id1 { id2 `when` anchor 2, `eq(0, 1)` { } with no child }. The source field `mode` sits outside the round.
- No packet: the body holds only an empty `when`, so it holds no member; a round would charge no slot and write no byte. Construction must fail, before any pack or unpack, as in `construct_empty_times_body`.
- Expected: `scheme_error` (C++: `Error::SchemeInvalid` at construction, since AZ-2416).
- Source: loop 22, AZ-2416, AZ-2417.

## construct_empty_when_repeat_body

- Scheme: id0 `u8 mode`; id1 `repeat` anchor 1 { id1 `when` anchor 1, `eq(0, 1)` { } with no child }. The source field `mode` sits outside the round.
- No packet: as `construct_empty_when_times_body`.
- Expected: `scheme_error` (C++: `Error::SchemeInvalid` at construction, since AZ-2416).
- Source: loop 22, AZ-2416, AZ-2417.

## construct_empty_nested_when_body

- Scheme: id0 `u8 mode`; id1 `u8 c`; id2 `times` anchor 2, count = id1 { id2 `when` anchor 2, `eq(0, 1)` { id2 `when` anchor 2, `eq(0, 1)` { } with no child } }. The body of a `when` holds only an empty `when`.
- No packet: as `construct_empty_when_times_body`; a `when` that holds nothing but another empty `when` holds no member either.
- Expected: `scheme_error` (C++: `Error::SchemeInvalid` at construction, since AZ-2416).
- Source: loop 22, AZ-2416, AZ-2417.
