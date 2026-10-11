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
- Limit: `maxRounds` 3; `maxSlots` at its default (4,194,304).
- Packet `01 11 22 33 44`: type `01`; four one-byte rounds. The fourth round would be the fourth started, above the limit, so it is refused when it would start, with its byte `44` left.
- Expected: `too_many` or `bad_value`, with `needed` 0 and `left` 1. No handler call, no row. The label of the error is not asserted.
- Source: loop 15, AZ-2216 to AZ-2219 (round limits); the bytes were run against each package's real code.
- Run by: C# (`Scheme<T>.WithLimits(maxRounds: 3)`), TypeScript (`withLimits({ maxRounds: 3 })`), Java (`withLimits(3, Scheme.DEFAULT_MAX_SLOTS)`), Rust (`with_limits(3, DEFAULT_MAX_SLOTS)`), Python (`with_limits(max_rounds=3)`).
- Not run by: C++ (fixed `Array<T, N>` storage and `Error::TooMany`, so no round budget to set). Its replay skips the stage.

## times_rounds_over_limit

- Scheme: id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `u8 v` }.
- Limit: `maxRounds` 3; `maxSlots` at its default (4,194,304).
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
