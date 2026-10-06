# Python split-form flag bits numbered by scheme order, handle shareable

**Task**: AZ-2230_python_split_bits_scheme_order
**Name**: Python numbers split bits by scheme order
**Description**: `Scheme(...)` gives each split-form flag bit the number of its place among the bits that follow a read of its flag byte, as TypeScript, Java, Rust and C++ do (AZ-2135), instead of the order of the `.bit(...)` calls. One `flag_byte()` handle can then be a member of any number of schemes and can be read more than once.
**Complexity**: 3 points
**Dependencies**: AZ-2135_split_bits_field_order (the cross-language rule and the other packages' bytes), AZ-2100_python_split_form_repeat (Python split form and its scope checks)
**Component**: python
**Tracker**: AZ-2230
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment (`_docs/loops/loop16/assessment16.md` Q1), owner decision A on 2026-10-06. AZ-2135 numbers split bits by field order in TypeScript, Java and C++ (Rust already did) and does not list Python. README says "call them in scheme order".

Python numbers a bit when you call `.bit(...)` on the handle (`_FlagByte.bit` in `python/src/packbin/_nodes.py` appends the field to the handle and returns a bit with that index). The handle keeps every bit made from it, `Scheme(...)` refuses a bit that is not in the scheme (`_validate_flag_bits` in `_validate.py`), and the flag byte is written from all the handle's bits (`_pack.py`, `_FlagByte` branch). Observed on `2eb9875` (Python 3.14.6), against the target bytes of the other packages (the TypeScript file `typescript/tests/split-bits-field-order.test.ts` passes 10 of 10 here; the Rust bytes are in `rust/src/flag_presence_tests.rs:178` and `flag_bits_tests.rs:73`):

| # | Scheme (type 1, row a dict) | Python today | Target (TypeScript, Java, Rust) |
|---|-----------------------------|--------------|---------------------------------|
| 1 | one handle in two schemes, each `[m, m.bit(u8 x)]`, x=5 | the second `Scheme(...)` raises `ValueError: flag byte: bit 0 is not in the scheme`; the first scheme packs `010105` until the second `m.bit(...)` is called and `010305` after it | `010105` in both |
| 2 | `[m, early a, late b]`, `late` created first, b=9 | `010109`; its unpack `{b: 9}`; unpack of `010209` gives `{a: 9}` | `010209` |
| 3 | `[m, m.bit(a), m, m.bit(b)]`, b=9 | `01020209`; unpack of `01000109` gives `TrailingBytes(left=1)` | `01000109` |
| 4 | one handle shared by two schemes of five bits each (`f0` to `f4`) | the fourth `.bit(...)` of the second scheme raises `ValueError: flags already has 8 bits` | both build: `011007` for `{f4: 7}`, `02110307` for `{f0: 3, f4: 7}` |
| 5 | `[m, 8 bits, m, 8 bits]` | the ninth `.bit(...)` call raises `ValueError: flags already has 8 bits` | builds, `{a7: 1, b0: 2}` packs `0180010102` |
| 6 | `[k, m, when(1, eq(0, 1), [m, m.bit(x)]), m.bit(y)]`, `{k: 1, x: 5, y: 6}` and `{k: 0, y: 6}` | `010103030506` and `01000206`; unpack of `010101010506` gives `TrailingBytes(left=1)` | `010101010506` and `01000106` |
| 7 | `[m, m.bit(group(0, y, m.bit(x)))]`, `{y: 1}` | `010201` (the inner bit was created first and took bit 0) | `010101` |

The bytes of a scheme that was built once with its bits created in scheme order are already the target bytes (golden position in split form `4001000065cd1d00a3e1110100`, the AZ-2100 vectors, a `repeat` round `010105000107`, `[k, m, when(1, eq(0, 1), bit v)]` `010001` / `01010105`).

## Outcome

- `Scheme(...)` numbers the bits of every read of a flag byte by their place in the scheme: bit 0 is the first bit that follows the read, as in the combined `flags` form. A bit nested in another bit's field is numbered after the outer one.
- A `flag_byte()` handle holds no bit and no count: `.bit(...)` returns a bit that the scheme numbers. The handle can be a member of any number of schemes and can be read more than once; a second read starts its own bits. At most 8 bits follow one read.
- Each read of a flag byte in a scheme is its own: a byte read inside a taken `when` does not change the byte that a bit after the `when` reads.
- The wire bytes change only for a shared handle, a byte read twice, and bits created out of scheme order (rows 1 to 7 above). Every other scheme packs and unpacks byte for byte as today.

## Scope

### Included
- Python numbering and counting of split-form bits at `Scheme(...)` (`python/src/packbin/_nodes.py`, `_validate.py`, `_scheme.py`, and `_pack.py` / `_unpack.py` where they read the handle's bit list).
- Removing the refusal of a flag byte listed without all its bits (`flag byte: bit N is not in the scheme`), which only existed because the handle kept every bit.
- Moving the ninth-bit refusal from the `.bit(...)` call to `Scheme(...)`.
- The text that states the old Python rule: README (the split-form upgrade paragraph, the last sentences about Python; the construction bullet that says Python refuses a flag byte listed without all its bits and that the ninth bit fails at build only in TypeScript and Java), `_docs/02_document/components/03_python_package/description.md` (the known limitation, the Construction rule paragraph, the `Scheme` row) and its `tests.md` row for `test_split_form`, and the Python row of the AZ-2135 progress table.

### Excluded
- C# (AZ-2135 G4, held for the C# work).
- Scope rules of split bits (a bit before its byte, another scope, a byte read inside a `when`, `flags` member or flag bit that ends before the bit): unchanged, with the same messages.
- A `when`, `times` or `repeat` as a `flags` member or flag-bit field (O2, held), and the C++ scope parity (O5).
- `flags(...)` combined form and its own ninth-child refusal.

## Acceptance Criteria

**AC-1: One handle in two schemes**
Given `m = flag_byte()` and two schemes `Scheme(1, dict, m, m.bit(u8(0, x)))` and the same with type number 2, built in this order
When `{x: 5}` is packed with each
Then both build and give `010105` and `020105`, and the first scheme still gives `010105` after the second was built (today the second `Scheme(...)` raises `ValueError` `flag byte: bit 0 is not in the scheme`, and the first gives `010305`).

**AC-2: Numbers follow the scheme, not the order of the calls**
Given `late = m.bit(u8(1, b))` created before `early = m.bit(u8(0, a))` and the scheme `[m, early, late]`
When `{b: 9}` is packed, and `010209` and `010109` are unpacked
Then the bytes are `010209`, `010209` unpacks to `{b: 9}` and `010109` to `{a: 9}` (today `010109`, `{a: 9}` and `{b: 9}`).

**AC-3: A second read starts its own bits**
Given `[m, m.bit(a), m, m.bit(b)]`
When `{b: 9}` and `{a: 3, b: 9}` are packed, and `01000109` and `0101030109` are unpacked
Then the bytes are `01000109` and `0101030109`, and they unpack to `{b: 9}` and `{a: 3, b: 9}` (today `01020209`, `0103030309`, and `01000109` is `TrailingBytes(left=1)`). `scheme.with_limits(max_rounds=3)` packs `{b: 9}` as `01000109` too.

**AC-4: A handle shared by two five-bit schemes builds both**
Given one handle and two schemes of five `u8` bits `f0` to `f4` each (type 1 and 2)
When `{f4: 7}` is packed with the first and `{f0: 3, f4: 7}` with the second, and each result is unpacked
Then the bytes are `011007` and `02110307` and the rows come back (today the second scheme's fourth `.bit(...)` raises `flags already has 8 bits`).

**AC-5: Eight bits per read**
Given `[m, a0..a7, m, b0..b7]` (sixteen `u8` bits on one handle)
When `{a7: 1, b0: 2}` is packed and unpacked
Then it builds, packs `0180010102` and unpacks to `{a7: 1, b0: 2}` (today the ninth `.bit(...)` call raises).

**AC-6: The ninth bit of one read is refused when the scheme is built**
Given nine `.bit(...)` calls on one handle, all placed after one read of it (together, or with some inside a `when` that follows the read)
When `Scheme(...)` runs
Then it raises `ValueError` with the text `flags already has 8 bits`, and the ninth `.bit(...)` call itself raises nothing (today the call raises, with the same kind and text). The hostile vector `nine_flag_bits_split` (`fixtures/hostile/cases.txt`, stage `construct`, expected `scheme_error`) is still a scheme error.

**AC-7: A byte read inside a taken `when` does not change the outer byte**
Given `[u8(0, k), m, when(1, eq(0, 1), [m, m.bit(u8(1, x))]), m.bit(u8(2, y))]`
When `{k: 1, x: 5, y: 6}`, `{k: 0, y: 6}` are packed, and `010101010506`, `01000106` are unpacked
Then the bytes are `010101010506` and `01000106`, and they unpack to `{k: 1, x: 5, y: 6}` and `{k: 0, y: 6}` (today `010103030506`, `01000206`, and the two target hex strings are `TrailingBytes(left=1)`).

**AC-8: Nested bits number the outer bit first**
Given `[m, m.bit(group(0, u8(0, y), m.bit(u8(1, x))))]`
When `{y: 1}` and `{y: 1, x: 2}` are packed and unpacked
Then the bytes are `010101` and `01030102`, and they unpack to `{y: 1}` and `{y: 1, x: 2}` (today `010201` and `01030102`).

**AC-9: A bit that is not placed leaves its bit clear**
Given `m = flag_byte()`, `m.bit(u8(0, x))` created and never placed, and the scheme `[m]`
When `{}` is packed
Then the scheme builds and packs `0100` (today `Scheme(...)` raises `ValueError` `flag byte: bit 0 is not in the scheme`). TypeScript packs `0100` for the same shape (observed).

**AC-10: Schemes that pack today do not change, and the caller's nodes are not changed**
Given the golden position scheme in split form, `[k, m, when(1, eq(0, 1), m.bit(v))]` with `{k: 0, v: 5}` and `{k: 1, v: 5}`, the `repeat` round `[repeat(0, m, m.bit(u8 v))]` with `{v: [5, None, 7]}`, the language-pair `bitwhen` scheme (`.github/workflows/drivers/handoff.py`, `{k: 0, v: 5}`), one pair of nodes `m` and `bit = m.bit(u8(0, x))` placed in two schemes, and the scope-error schemes of `test_split_form.py`
When they are built, packed and unpacked
Then the bytes are `4001000065cd1d00a3e1110100` (equal to `fixtures/golden.hex`), `010001` and `01010105`, `010105000107`, `010001`, `010105` and `020105`, and every scope error keeps its kind and message.

## Non-Functional Requirements

**Compatibility**
- Python packs the bytes of the other four packages that number by scheme order for every shape of AC-1 to AC-8; rows that pack today keep their bytes except rows 1 to 7 of the Problem table, whose old bytes were unreadable by the other packages.
- Error kinds and texts of the existing refusals are unchanged (C15); the ninth-bit refusal changes only the moment it is raised.

**Reliability**
- Building a scheme does not change the handle or the bit nodes the caller holds, so schemes built from them later, in any order, number their bits by their own scheme.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | handle in two schemes; first scheme packed after the second is built | `010105`, `020105`; no `ValueError` | `python/tests/test_split_bits_field_order.py` (new) |
| AC-2 | early/late creation, pack and both unpacks | `010209`; `{b: 9}`; `{a: 9}` | `python/tests/test_split_bits_field_order.py` |
| AC-3 | flag byte read twice; unpack of the target bytes; `with_limits` | `01000109`, `0101030109`; rows back | `python/tests/test_split_bits_field_order.py` |
| AC-4 | two five-bit schemes on one handle | `011007`, `02110307`, rows back | `python/tests/test_split_bits_field_order.py` |
| AC-5 | two reads of eight bits | `0180010102`, row back | `python/tests/test_split_bits_field_order.py` |
| AC-6 | nine bits in one read, and four before / five inside a `when` | `ValueError` `flags already has 8 bits` from `Scheme(...)`, none from `.bit(...)` | `python/tests/test_split_bits_field_order.py`; the builder of `nine_flag_bits_split` in `python/tests/test_bool_placement.py` (`CONSTRUCT_SCHEMES`, `_nine_bits_split`) builds a `Scheme` and its comment line changes |
| AC-7 | read inside a taken `when`, taken and not taken | `010101010506`, `01000106`; rows back | `python/tests/test_split_bits_field_order.py` |
| AC-8 | nested bits | `010101`, `01030102` | `python/tests/test_split_bits_field_order.py` |
| AC-9 | unplaced bit | builds, `0100` | `python/tests/test_split_bits_field_order.py`; replaces `test_ac3_flag_byte_listed_without_its_bits_is_scheme_error` in `python/tests/test_split_form.py` |
| AC-10 | existing split-form tests and the shared-node case | unchanged bytes and messages | `python/tests/test_split_form.py` (existing tests unchanged), `python/tests/test_position.py`, `python/tests/test_round_lists.py`, `python/tests/test_flag_group_presence.py`; shared nodes in `python/tests/test_split_bits_field_order.py` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-10 | `fixtures/golden.hex`, the Python driver `.github/workflows/drivers/handoff.py` `bitwhen` ring | split-form position and the `bitwhen` hand-off | identical hex, 0 mismatched bytes | Compatibility |
| AC-2, AC-3 | the TypeScript test bytes `010209` and `01000109` | Python unpacks them | the rows of AC-2 and AC-3 | Compatibility |

## Constraints

- ADR-001: Python only. TypeScript `bindFlagBits` (`typescript/src/flag-scope.ts`) and Java `SchemeOrder.bindFlagBits` are the behavioural reference; no code is shared or imported.
- Files at or under 500 lines (`_validate.py` is 158, `_nodes.py` 425, `test_split_form.py` 235).
- Error kind and label of existing errors unchanged (decision C15): the scope errors and the ninth-bit text `flags already has 8 bits` keep their kind (`ValueError`) and message.
- No public API change: `flag_byte()` and `.bit(field)` keep their names and call shape.
- Bytes in the ACs were observed on `2eb9875` (TypeScript and the Python "today" column by running the code; the "target" bytes of AC-1 to AC-8 also by a throwaway change to a scratch copy of `python/` that gave every target byte above and failed only the two tests named in the Unit Tests table). The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller who called `.bit(...)` out of scheme order gets different bytes**
- *Risk*: bytes of a scheme whose bits were created out of order, or whose handle was shared or read twice, change (AC-2, AC-3, AC-7, AC-8).
- *Mitigation*: the old bytes were read as different fields by the other packages (Python read the target bytes wrongly too). README upgrade note replaces "Python still numbers bits by the order of the `.bit()` calls".

**Risk 2: A bit created and never placed no longer fails**
- *Risk*: AZ-2100 refused `flag byte: bit N is not in the scheme` because the handle kept every bit. A handle that holds no bit cannot tell a bit left out by mistake from a bit placed in another scheme, so the byte is written with that bit clear (AC-9), as in TypeScript.
- *Mitigation*: stated in the README upgrade note and the Python component description; the old test is replaced, not deleted.

**Risk 3: The scheme copies the nodes it numbers**
- *Risk*: a read of a flag byte needs an identity of its own (AC-7: a byte read inside a `when` must not overwrite the one a later bit reads), so the scheme holds rebuilt nodes; code that reads `Scheme._fields` (private) sees copies.
- *Mitigation*: nothing public reads `_fields`; the unpack and pack branches for flag bytes change to read the per-read bit list.

## Owner decision (2026-10-06)

DECIDED, assessment Q1 option A (the recommendation, "implement everything now"): add Python to AZ-2135. Python numbers split bits by their place in the scheme per flag-byte read and lets a handle be shared, with the Rust bytes for the AZ-2135 probes. The wire changes only for shared handles, a byte read twice or bits created out of scheme order; Python only.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2). Python numbers split flag bits as TypeScript, Java, Rust and C++ do: by place among the bits that follow each read of the flag byte, outer bit first for nested bits. A `flag_byte()` handle and the bits `.bit(...)` returns hold no number (index -1), so one handle can be a member of any number of schemes and be read more than once.

What shipped:
- New `python/src/packbin/_flag_scope.py` (83 lines): `_bind_flag_bits`. `Scheme.__init__` runs `_validate_order`, then `_bind_flag_bits`, then `_validate_round_nesting` on the bound nodes, and keeps the bound copies in `_fields`. Each read becomes a `_FlagByte` of its own that lists its bits by number; `repeat` and `times` leaves are recomputed. `_validate_flag_bits`, `_check_flag_scopes` and `_bit_label` left `_validate.py`; `_pack.py` and `_unpack.py` are unchanged.
- The ninth bit of one read raises `ValueError: flags already has 8 bits` from `Scheme(...)`, not from `.bit(...)`. A bit that is created and never placed leaves its bit clear (it raised `flag byte: bit N is not in the scheme`).
- Wire change only for a shared handle, a byte read twice, or bits created out of scheme order: `[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09` (was `01 02 02 09`); `[m, early, late]` with only `late` set packs `01 02 09` (was `01 01 09`).

Tests: `python/tests/test_split_bits_field_order.py` (new, 16 tests): AC-1 `test_ac1_one_handle_is_a_member_of_two_schemes`; AC-2 `test_ac2_numbers_follow_the_scheme_not_the_order_of_the_calls`; AC-3 `test_ac3_a_second_read_starts_its_own_bits`; AC-4 `test_ac4_a_handle_shared_by_two_five_bit_schemes_builds_both`; AC-5 `test_ac5_a_flag_byte_read_twice_holds_eight_bits_each`; AC-6 three tests (`..._the_ninth_bit_of_one_read_is_refused_by_the_scheme_not_by_bit`, `..._is_counted_across_a_when_that_follows_the_read`, `..._eight_bits_in_one_read_build`) and the hostile vector `nine_flag_bits_split` in `test_bool_placement.py`; AC-7 `test_ac7_a_byte_read_inside_a_taken_when_does_not_change_the_outer_byte`; AC-8 `test_ac8_a_bit_nested_in_another_bits_field_is_numbered_after_the_outer_one`; AC-9 `test_ac9_a_bit_that_is_not_placed_leaves_its_bit_clear` and `test_split_form.py::test_ac3_flag_byte_listed_without_its_bits_leaves_them_clear` (replaces the refusal test); AC-10 four tests, including the position scheme in split form packing the golden `4001000065cd1d00a3e1110100`. The Python suite is 326 passed (HEAD 286; this spec +16, AZ-2231 +24). Written first: 11 of the new tests failed at HEAD (the AC-10 tests pin unchanged bytes and passed).

Evidence: 12,000 random split-form schemes (one read per handle, bits in scheme order) pack and unpack byte-identically at HEAD and now; 3,000 schemes with multi-read, unplaced and `when`-body reads give Python and TypeScript identical bytes and results (HEAD Python differed on 581 packs); the reviewer ran 60,000 schemes HEAD against now (0 differences) and 22,000 harder ones against TypeScript (identical); seven mutants (a `when` sharing reads, nested bits numbered inner first, a repeated read reusing the first, an early ninth-bit refusal, a shifted unpack bit, a reversed pack order, the `memoryview` guard of AZ-2231) were each caught.

Review findings (PASS_WITH_WARNINGS, no High):
- F4 (no test pinned that a read inside a `group` stays visible after it): fixed, `test_split_bits_field_order.py::test_a_flag_byte_read_inside_a_group_serves_a_bit_after_the_group` (`010105`, same as TypeScript); copying `reads` in the `_Group` branch of `_bind` now fails it and no other test.
- F1 (docs still stated the old rule): fixed in the docs pass (README patch, `description.md`, `tests.md`, `module-layout.md`, `01_solution/schema.md`).
- F3 (open, owner): a bit created and never placed leaves its bit clear without a message; only a trailing bit goes unnoticed, an omission in the middle fails the id order. TypeScript does the same; Risk 2 of this spec. Pinned by `test_ac9_...`.

Discoveries: the hostile README line for `nine_flag_bits_split` ("Python already rejects it") stays true, the vector is raised by `Scheme(...)` now; `fixtures/hostile/README.md` says so (documented). Held, unchanged: C# (AZ-2135 G4), a `when`, `times` or `repeat` as a `flags` member (AZ-2128, AZ-2120), C++ scope parity.
