# Rust pack decides `when` and counts from what it wrote, and refuses a `times` list longer than the count

**Task**: AZ-2237_rust_map_pack_when_written_values
**Name**: Rust pack reads what it wrote
**Description**: Rust `pack` (the map form and the typed `Scheme<T>`, which share one walker) decides every `when` and takes every count from the values it wrote in the same scope, as unpack does, and a map `times` packed from per-name lists returns `PackError::Type` naming the member when a list holds more items than the count.
**Complexity**: 3 points
**Dependencies**: AZ-2189_rust_map_times_list_under_flags (the map `times` per-name rule), AZ-2197_typescript_when_on_written_values and AZ-2185_typescript_times_list_longer (the rules in TypeScript; Python, Java and C# agree)
**Component**: rust
**Tracker**: AZ-2237
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment (`_docs/loops/loop16/assessment16.md` G1), owner scope on 2026-10-06. Two disagreements between Rust pack and its own unpack, found while walking AZ-2197 ("Java and Rust are not affected by this shape" is wrong for Rust). Observed on `2eb9875` (cargo 1.79, scratch copy of `rust/`); the packages that already follow the rule are TypeScript, Python and Java (and C# for the `when`).

**1. A `when` and a count read the values pack is given, not the ones it wrote.** `rust/src/walk/pack.rs`: the `When` arm tests `require(values, field)` on the row, and `Sized`, `Bits`, `Packed` and `Times` read their count from the row. Unpack tests the fields it has read. Both the map form and the typed `Scheme<T>` (`BinaryPacker::pack` builds the values from the row and calls the same `walk::pack`) show it:

| # | Scheme and values | Pack today | Own unpack of those bytes |
|---|-------------------|-----------|---------------------------|
| A | `u8 "0"; when(1, eq("0", 0), [u8 "1"]); when(2, eq("1", 0), [u8 "2"])`, `0=1, 1=0, 2=4` | `010104` | `Trailing { left: 1 }` |
| B | the same as a typed `Scheme<Row>` (`p: u8`, `n: Option<u8>`, `v: Option<u8>`), `Row { p: 1, n: Some(0), v: Some(4) }` | `010104` | `Err(Trailing { left: 1 })` |
| C | `flags(0, "f", [group(0, "on", [])]); when(1, eq("on", 0), [u8 "1"])`, `on=0, 1=7` (`eq(bool, false)` on a clear bit) | `010007` | `Trailing { left: 1 }` |
| F1 | `u8 "0"; when(1, eq("0", 0), [u8 "1"]); sized("2", "1")`, `0=1, 1=2, 2=aabb` (the count names the skipped `1`) | `0101aabb` | `Short { field: "2", needed: 0, left: 2 }` |
| F2 | the same with `bits("2", "1")`, `2=[1,0]` / `packed(2, "2", "1", 0)`, `2=[1,2]` / `times(2, "1", [u8 "2"])`, `2=[7,8]` | `010101` / `010109` / `01010708` | `Short` with `needed: 0` (fields `"2"`, `"2"`, `"times"`) |
| G1 | `repeat(0, [u8 "0"; when(1, eq("0", 1), [u8 "1"]); when(2, eq("1", 5), [u8 "2"])])`, one round `0=0, 1=5, 2=3` | `010003` | reads two rounds, `[{"0": 0}, {"0": 3}]`: wrong data, no error |
| G2 | `u8 "0"; times(1, "0", [u8 "1"; when(2, eq("1", 1), [u8 "2"]); when(3, eq("2", 5), [u8 "3"])])`, count 1, `__times_1` = one round `1=0, 2=5, 3=3` | `01010003` | `Trailing { left: 1 }` |

**2. A map `times` drops the extra items of a list longer than the count.** `slice_times` takes item `i` of each per-name list for rounds `0..count` and nothing else. `u8 "0"; times(1, "0", [u8 "1"])` with `0=2, 1=[1,2,3]` packs `01020102` (the 3 is dropped); count 0 with `1=[1]` packs `0100`; with a second member, `2=[3,4,5]` beside `1=[1,2]` packs `010201030204`; a direct member beside a `flags` member with `2=[5,6,7]` packs `010200050006`. TypeScript (AZ-2185), Python (AZ-2186) and Java (AZ-2187) refuse it, naming the member, the items and the count. A shorter list already fails (`PackError::Missing("1")`), and a longer list kept beside `__times_<anchor>` rounds already fails (`times at id 1: list for '1' disagrees with its rounds`). The typed `times` always carries one round per element, so it has no per-name list.

## Outcome

- Pack keeps, for the scope it is writing (the top level, each round of a `repeat` or `times`, each list or dict element), the value it wrote for each field under its name, as unpack holds them: an integer field, each slot of a `u2`, a `flags` byte and a flag byte under their own name, and a set bool as `1`. Every `when` tests that record and every count (`sized`, `bits`, `packed`, `times`) reads it. A field that was skipped or never written does not match a `when`; `eq(bool, false)` on a clear bit does not match.
- A count that names a field pack did not write is `PackError::Missing(<count field name>)`, the error the row already gives when it holds no value for the count.
- A map `times` without `__times_<anchor>` returns `PackError::Type` for the first direct member whose list has more items than the count, with the text `times at id {anchor}: '{name}' has {items} items, count is {count}`.
- Every row whose bytes unpack read back as the same row before keeps those bytes.

## Scope

### Included
- `rust/src/walk/pack.rs` (the `When` arm, the count reads, the record of written values, a fresh record per round and per element) and `rust/src/walk/times.rs` (the longer-list check, next to `check_aligned`); both forms, since the typed scheme calls the same walker.
- The `pack` rustdoc in `rust/src/walk/mod.rs`, and the text that states the old limitation: README (the `eq(id, false)` paragraph and the paragraph that says Rust pack still tests the values you give it), `_docs/02_document/components/04_rust_package/description.md` (the known limitation "Pack decides a `when` from the values it is given", the `times` per-name paragraph, the loop 16 changes list).

### Excluded
- Which kinds a `when` or a count may name, and the rest of the Rust construction rules (AZ-2126, held).
- The error kind and label of existing errors (C15); no new `PackError` variant (it is a public enum).
- `check_aligned` (a value under a `flags` or `when` member without rounds), `check_lists` (a list beside rounds), flag-bit and `flags` presence decisions (`member_on`), and the held `when`, `times` or `repeat` as a `flags` member (AZ-2128, AZ-2120).
- Typed `times` (rounds only), Python, Java, TypeScript, C# and C++.
- A lone non-list value for a member of a `times` round (it is read for round 0 only; `0=2, 1=5` stays `PackError::Missing("1")`).

## Acceptance Criteria

**AC-1: A skipped field does not match on pack (map form)**
Given the scheme of probe A and `0=1, 1=0, 2=4`
When it is packed and the bytes are unpacked
Then the bytes are `0101` and unpack returns `{"0": 1}` (today `010104` and `Trailing { left: 1 }`).

**AC-2: The typed scheme agrees**
Given the typed scheme of probe B and `Row { p: 1, n: Some(0), v: Some(4) }`
When it is packed with `BinaryPacker::pack` and read with `unpack_with`
Then the bytes are `0101` and the row read is `Row { p: 1, n: None, v: None }` (today `010104`, `Trailing { left: 1 }`).

**AC-3: `eq(bool, false)` on a clear bit does not write its body**
Given the scheme of probe C
When `on=0, 1=7` and `1=7` (no `on`) are packed, and the same scheme with `eq("on", 1)` is packed with `on=1, 1=7` and `on=0, 1=7`
Then the bytes are `0100` and `0100`, then `010107` and `0100`, and each unpacks (today the first is `010007` with `Trailing { left: 1 }`).

**AC-4: A count names only a field that was written**
Given the schemes of F1 and F2 with `0=1` (the `when` skips `1`)
When each is packed
Then each returns `PackError::Missing("1")` and no bytes (today `0101aabb`, `010101`, `010109`, `01010708`). With `0=0` the `sized` scheme still packs `010002aabb`.

**AC-5: Rounds decide from what the round wrote**
Given the schemes of G1 (a `repeat` round) and G2 (a `times` round)
When G1 is packed with the one round `0=0, 1=5, 2=3`, and G2 with count 1 and the one round `1=0, 2=5, 3=3`
Then the bytes are `0100` and `010100`, and they unpack to one round `{"0": 0}` and to `1=[0]` (today `010003`, read as two rounds with the wrong data, and `01010003`, `Trailing { left: 1 }`).

**AC-6: A longer per-name list is refused**
Given `u8 "0"; times(1, "0", [u8 "1"])` with no `__times_1`
When `0=2, 1=[1,2,3]` and `0=0, 1=[1]` are packed
Then each returns `PackError::Type` with `times at id 1: '1' has 3 items, count is 2` and `times at id 1: '1' has 1 items, count is 0` (today `01020102` and `0100`). With `[u8 "1", u8 "2"]` in the body, `0=2, 1=[1,2], 2=[3,4,5]` gives `PackError::Type("times at id 1: '2' has 3 items, count is 2")` (today `010201030204`), and with `flags(1, "f", [u8 "1"])` then `u8 "2"` in the body, `0=2, 2=[5,6,7]` gives the same error for `'2'` (today `010200050006`).

**AC-7: Lists that fit, an empty or absent list, and the earlier errors are unchanged**
Given the schemes of AC-6
When `0=2, 1=[1,2]`, `0=2, 1=[1]`, `0=0, 1=[]`, `0=0` and `0=2, 1=5` are packed, and `0=2, 1=[1,2,3]` is packed with `__times_1` rounds, and the `flags` body of AC-6 with `0=2, 1=[9], 2=[5,6]`
Then the results are `01020102`, `PackError::Missing("1")`, `0100`, `0100`, `PackError::Missing("1")`, `PackError::Type("times at id 1: list for '1' disagrees with its rounds")`, and `PackError::Type("times at id 1: '1' is under a flags or when; give its values per round under '__times_1'")`, all as today.

**AC-8: Rows that packed readable bytes do not change**
Given the 288 existing Rust tests and these rows (each unpacks to the row today)
When they are packed
Then the bytes are as today: the chain of probe A with `0=0, 1=0, 2=4` `01000004` and with `0=0, 1=1, 2=4` `010001`; the chain `u8 "0"; when(1, eq("0", 1), [u8 "1"]); when(2, eq("1", 5), [u8 "2"])` with `0=1, 1=5, 2=9` `01010509`; the G1 repeat with one round `0=1, 1=5, 2=3` `01010503`, and with that round then `0=0` `0101050300`; G2 with the round `1=1, 2=5, 3=3` `0101010503`; the `bitwhen` scheme (`flag_byte("m")`, `when(2, eq("k", 1), [m.bit(u8 "v")])`) `010001` for `k=0, v=5` and `01010105` for `k=1, v=5`; `u2(["0","1"])` then `when(2, eq("1", 2), [u8 "2"])` with `0=1, 1=2, 2=9` `010909`, and with `1=1` `0105`; `flags(0, "f", [u8 "0"])` then `when(1, eq("0", 3), [u8 "1"])` with `0=3, 1=9` `01010309`.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that unpack reads back as the same row are unchanged. Only rows whose bytes were unreadable, misread, or lost a value change (they now fail, or pack fewer bytes).

**Reliability**
- Pack returns bytes the peer reads as the same row, or an error; it never writes a body its own unpack skips, takes a count unpack cannot read, or drops a list item.

**Performance**
- The record holds one entry per field written in a scope; no new allocation per field beyond that, and the AC-10 loop test (`rust/src/packbin_tests.rs`) is unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | probe A through `pack` and `unpack` | `0101`, `{"0": 1}` | `rust/src/when_written_tests.rs` (new; register it in `rust/src/lib.rs` under `#[cfg(test)]`, as the other `*_tests.rs`) |
| AC-2 | probe B through `BinaryPacker::pack` and `unpack_with` (built as in `rust/src/flag_bits_tests.rs`) | `0101`, `Row { p: 1, n: None, v: None }` | `rust/src/when_written_tests.rs` |
| AC-3 | probe C, four rows | `0100`, `0100`, `010107`, `0100` | `rust/src/when_written_tests.rs` |
| AC-4 | F1 and F2 with `0=1`; the `sized` scheme with `0=0` | `PackError::Missing("1")` ×4; `010002aabb` | `rust/src/when_written_tests.rs` |
| AC-5 | G1 and G2 | `0100`, `010100`, and their unpacks | `rust/src/when_written_tests.rs` |
| AC-6 | the four rows | the exact `PackError::Type` texts | `rust/src/times_longer_tests.rs` (new; registered in `rust/src/lib.rs`) |
| AC-7 | the seven rows | the results listed | `rust/src/times_longer_tests.rs` (the last two beside the existing `disagrees with its rounds` and `under a flags or when` tests in `rust/src/times_tests.rs` and `times_stale_tests.rs`, which stay unchanged) |
| AC-8 | the rows listed; the whole suite | bytes as today; 288 existing tests pass | `rust/src/when_written_tests.rs`; existing `rust/src/*_tests.rs` and `rust/tests/*.rs` unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-8 | `language-pair.sh` rings that include the Rust driver (`.github/workflows/drivers/handoff-rust`) | pack and unpack in both directions | 0 mismatched bytes | Compatibility |
| AC-8 | `fixtures/golden.hex`, the route hex in `rust/tests/times_route_tests.rs` | pack | unchanged hex | Compatibility |

## Constraints

- ADR-001: Rust's own walker; TypeScript AZ-2197 / AZ-2185, Python and Java are the behavioural reference only.
- Pack errors are `PackError` values (`Missing`, `Type`); construction failures stay panics; no public API change and no new variant. `PackSession::pack` passes the new errors through unchanged (`SessionPackError::Pack`).
- Files at or under 500 lines: `rust/src/walk/pack.rs` is 435 lines now and the change adds about 40; if it passes 500, move the flag-bit helpers (`collect_flag_bits`, `member_on`, `group_on`, `any_member_on`) to their own file in `rust/src/walk/`. `times_tests.rs` is 461 lines, so the new tests go in new files.
- Error kind and label of existing errors unchanged (decision C15): the `PackError::Missing` of a missing count, the AZ-2189 and AZ-2118 messages and the `disagrees with its rounds` message keep their text.
- Probes A to G, the longer-list rows and AC-8 were run on `2eb9875`; the target bytes and errors come from a throwaway change to a scratch copy of `rust/` (a record of written values and a longer-list check): it gave every target above and passed all 288 existing tests. The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A scheme that relied on a `when` testing a given value that pack skipped**
- *Risk*: a chain whose middle field is skipped wrote the tail; the packet was unreadable by Rust's own unpack (AC-1, AC-4) or misread (AC-5), so no correct consumer depended on it.
- *Mitigation*: README upgrade note; the limitation sentences are replaced.

**Risk 2: A hand-built row that kept a longer list on purpose**
- *Risk*: a map `times` row whose lists were longer than the count packed with the tail dropped and now fails.
- *Mitigation*: the dropped items were never in the packet; the error names the member, the items and the count, as in the other three packages.

**Risk 3: The typed scheme is changed too**
- *Risk*: the ticket names the map form; the typed scheme goes through the same walker and showed the same bytes (probe B), so it changes with it.
- *Mitigation*: AC-2 pins it; a typed row that packed readable bytes keeps them (AC-8).

## Owner decision (2026-10-06)

DECIDED, assessment G1 (the recommendation, "implement everything now"): map pack decides every `when` from the fields it wrote in that scope (and a count that names a skipped field is an error), and refuses a longer `times` list with `PackError::Type` naming the member. Rows that packed readable bytes do not change (differential against HEAD). Reading the code, the typed `Scheme<T>` shares the walker and shows the same `when` bytes, so the rule covers it; the longer-list refusal is map-only because a typed `times` always carries its rounds.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2). Rust pack (map form and typed `Scheme<T>`, both through `walk::pack`) decides every `when` and takes every count from what it wrote in the same scope, as unpack does from what it read, and a map `times` without rounds refuses a list longer than the count.
- `rust/src/walk/pack.rs`: `Written`, one record per scope (the top level, each round of a `repeat` or `times`; list and dict elements use `Written::unread()`, which stores nothing); a field behind an untaken `when` or a clear bit is not written, so a `when` on it does not match and a count that names it is `PackError::Missing(<count>)`; a `flags` byte and a split flag byte are recorded as the byte pack wrote and a set bool as `1`; `pack_round` returns what a round wrote and `RoundLists` publishes it as one list per name into the parent after a `times` (as unpack does), not after a `repeat`.
- `rust/src/walk/flag_bits.rs` (new, 78 lines): `collect_flag_bits`, `group_on`, `any_member_on`, `member_on` and `bool_on`, moved out of `pack.rs` (436 to 496 lines with the fixes, under the cap).
- `rust/src/walk/times.rs`: `check_longer` (data members only, via `data_name`), called after `check_aligned` on the no-rounds branch: `times at id 1: '1' has 3 items, count is 2`.
- `walk/mod.rs` rustdoc, `lib.rs` three registrations (four with the fix pass).

Tests, all in `rust/src/`: `when_written_tests.rs` (11: `ac1_a_when_on_a_skipped_field_does_not_match_on_pack`, `ac2_the_typed_scheme_agrees`, two AC-3, five AC-4 for `sized`, `bits`, `packed`, `times` and a written count, two AC-5 for `repeat` and `times` rounds); `when_kept_tests.rs` (7, all `ac8_*`: chains, rounds, a split flag byte, a `u2` slot and a flags byte keep their bytes; the spec put AC-8 in `when_written_tests.rs`, which would exceed 500 lines); `when_names_tests.rs` (11, review fixes); `times_longer_tests.rs` (14: five `ac6_*`, six `ac7_*` and three review tests). Rust 331 pass (253 lib + 78 integration) in debug and release (HEAD 288). Written first: the 14 AC-1 to AC-6 tests failed at HEAD with the spec's bytes (`010007`, `010104`, `0101aabb`, `010003`, `01020102`, ...); AC-7 and AC-8 pass at HEAD by nature.

Evidence: differential harness against a HEAD copy, map form and typed form, three seeds of 200,000 row pairs each on the final code: 0 violations, 0 regressions (every new refusal falls in a bucket the spec names); the reviewer's about 10 M row comparisons over about 100,000 random schemes found no panic, and schemes without `when`, count, `times` or flags show 0 differences (C15 holds). `fixtures/golden.hex`, `rust/tests/times_route_tests.rs` and the hostile fixtures pass unchanged. Mutants killed: `when` read from the row, each of the four counts read from the row, `check_longer` removed, a repeat round sharing the parent record, the bool record removed, the `Flags` byte record removed (3 tests fail) and the `FlagByte` record removed (4 tests fail).

Review findings (PASS_WITH_WARNINGS), all fixed in a fix pass:
- F1 (medium): after a `times`, the names its rounds wrote were not lists in the parent record, so unpack-then-repack of `0101000007` returned `Missing("4")`, and a row holding `4=9` packed `010100000709`, which its own unpack rejects. Fixed with `RoundLists`; tests `a_name_a_times_round_wrote_is_a_list_after_it_so_a_when_on_it_does_not_match`, `a_body_kept_for_a_when_after_a_times_is_not_written` (`0101000007`), `the_same_holds_when_the_times_is_packed_from_per_name_lists`, `a_times_without_rounds_leaves_the_name_it_did_not_write_as_it_was` (`01000009`), `a_count_after_a_times_that_names_a_round_name_is_not_an_integer`.
- F2 (medium): `check_longer` refused a list under a `flags`, flag-byte or group name that pack never reads (the README edit path failed with `'n' has 3 items`). Fixed: those names are skipped, flag-bit inners stay checked; tests `a_list_under_the_name_of_a_flags_member_is_not_refused`, `a_row_edited_down_to_a_smaller_count_keeps_the_flag_byte_list_unpack_gave` (`010200010a0b000c`), `a_flag_bit_inner_longer_than_the_count_is_still_refused`.
- F3 (medium, test gap): nothing pinned that a `when` or count naming a flags byte or a split flag byte reads the byte pack wrote. Fixed: six tests in `when_names_tests.rs` (`0105010709`, `0101010508`, `010105aa`, ...).
- F4 (low, performance): an unread record was allocated per list and dict element. Fixed (`Written::unread()`, room for 8 entries up front). Release timings, min of 9, HEAD / before / now: position pack x100k 17.1 / 26.5 / 21.9 ms; 12 flat `u8` x300k 89.3 / 158.2 / 140.0 ms; 60k-element list x300 1818.6 / 2703.4 / 1832.7 ms; debug `nfr_round_trips_under_one_second` 563 to 615 ms against 545 ms at HEAD and a 1000 ms limit.
- F5 (docs): the rustdoc of `pack` was off (a plain field with no value is `Missing`; only flags members and flag-bit fields are skipped; a bool is read from its own value) and the README and description text still stated the old limits: fixed in `walk/mod.rs` and in the docs pass.
- F6 (low): a longer list is refused before item errors, as TypeScript does: documented in the README upgrade note.

Open (Low, owner): a flat scheme packs about 1.5 times slower in release (the entry, the name clone and the drop cost about 15 ns per written field); recording only when the scheme has a `when` or count would remove it and needs a flag computed in `MapScheme::new`; a multi-name `u2` in a map `times` fed per-name lists is not sliced past its first slot (`Missing("2")`, pre-existing); `Written` lookups scan linearly (slow only for schemes with thousands of fields and many `when`s).
