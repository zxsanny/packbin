# Python split-form flag byte, clean repeat lists, containers inside repeat/times

**Task**: AZ-2100_python_split_form_repeat
**Name**: Python split form and repeat/times fixes
**Description**: `flag_byte()` / `.bit(...)` work inside a `Scheme`; repeat/times lists hold exactly one value per round; `repeat`/`times` with `flags`, `when` or `group` children pack per item.
**Complexity**: 3 points
**Dependencies**: AZ-2071_python_hostile_unpack, AZ-2083_python_bool_flag_limit (same modules; bool rule applies to split form)
**Component**: python
**Tracker**: AZ-2100
**Epic**: AZ-2069

## Problem

Reproduced on `d108141` (Python 3.14, scratch scripts importing `python/src`). TypeScript output is given as the cross-language reference where TS is correct.

**1. Split form cannot be constructed.** `_validate_order` (`_nodes.py:400-424`) validates a `_FlagByte`'s bit fields once under the byte (`416-417`, via `node.bits`) and again at each `_FlagBit` (`418-419`). Every split-form scheme therefore fails:
- `m = flag_byte(); b = m.bit(u16(1, h)); Scheme(1, dict, u8(0, a), m, b)` raises `ValueError: field id 1 is not the next order 2`.
- `flag_byte` is exported (`__init__.py:14`) and documented (`schema.md` "Split form"), but no Python test uses it.
- Once it constructs, two more gaps appear:
  - **Bool lost.** A `bool` as the field of a flag-byte bit is never set on unpack: the `_FlagBit` branch (`_unpack.py:252-261`) recurses into `_Bool`, which does `pass` (`220-221`). Neither the row nor `seen` gets `True`.
  - **Late failure.** A bit placed before its flag byte fails only at unpack time with `RuntimeError("flag bit before flag byte")` (`_unpack.py:254-255`).

TS reference (correct today) for `u8(0, sid)`, `m`, `when(1, eq(0, 9), u8(1, shape))`, `m.bit(u16(2, heading))`: `{sid:9, shape:4, heading:90}` → `010901045a00`; `{sid:1}` → `010100`.

**2. Repeat/times lists absorb row defaults.** `_append` (`_unpack.py:77-87`) turns an existing non-list member into `[old, new]` and appends to an existing list. Unpack writes into a fresh `row_type()`, so defaults leak in:
- With `@dataclass class Trail: sid: int = 0; lat: object = 0; lon: object = 0` and `Scheme(1, Trail, u16(0, sid), repeat(1, i32(1, lat), i32(2, lon)))`, packing `Trail(1, [10, 30], [20, 40])` gives `0101000a000000140000001e00000028000000`.
- Unpacking those bytes gives `lat=[0, 10, 30]`, `lon=[0, 20, 40]`.
- A class-level list default (`class Trail2: lat = []; lon = []; sid = 0`) is appended to in place. The first unpack gives `lat [10, 30]` and also sets `Trail2.lat` to `[10, 30]`. The second unpack gives `[10, 30, 10, 30]`.
- `times` behaves the same: with `n: int = 0`, `lat: object = 0` and `times(1, 0, i32(1, lat), i32(2, lon))`, `01020a000000140000001e00000028000000` unpacks as `lat=[0, 10, 30]`.

TS starts each list empty.

**3. Containers inside repeat/times fail on pack.**
- **repeat:** `_Repeat` (`_pack.py:262-283`) calls `child.get(row)` on every child to measure lengths, and `_Flags`/`_When`/`_Group`/`_Times` have no `get`. `Scheme(1, dict, u8(0, a), repeat(1, flags(1, u8(1, v))))` with `{"a": 1, "v": [1, None]}` raises `AttributeError: '_Flags' object has no attribute 'get'`. TS packs `0101010100`.
- **times:** flag presence (`_child_on`, `_pack.py:57-66`) reads `child.get(row)`, the whole list, not item `i`. So in `Scheme(1, dict, u8(0, n), times(1, 0, flags(1, u8(1, v))))` with `{"n": 2, "v": [5, None]}` both bits are set, and the second round raises `TypeError: 1: expected int, got NoneType`. TS packs `0102010500`.

## Outcome

- Split-form schemes construct, pack the TS reference bytes, and round-trip, including a split-form `bool`.
- A flag bit placed before its flag byte, or whose flag byte is not in the scheme, fails at `Scheme(...)` with `ValueError`.
- Each repeat/times member list contains exactly the values read in that run. Defaults and shared class-level lists are never appended to.
- `repeat`/`times` with `flags`, `when` or (anchored) `group` children pack per item and match the TS bytes.

## Scope

### Included
- Order validation for split form: the flag byte takes no id, and each bit's field is validated at the bit's position.
- Bit position = the bit's place among that byte's bits in scheme order. `.bit()` call order equals scheme order in every documented example.
- Split-form `bool` unpack sets `True` (and records it for `when`).
- Fresh lists per repeat/times run on unpack.
- Per-item value resolution for every leaf under `repeat`/`times`, including leaves under `flags`, `when` and anchored `group`, and flag presence per item.

### Excluded
- Element row style for list/dict of group with attribute accessors (B14, user decision pending).
- Positional alignment of optional members inside `repeat` (absent items are not appended, same as TS). Superseded 2026-10-05 (loop 12 U2, owner: aligned everywhere): AZ-2134 makes Python, TS and C# keep one entry per round.
- Error labels (C15). Walker split (C21).

## Acceptance Criteria

**AC-1: split form constructs and matches TS**
Given `u8(0, sid)`, `m = flag_byte()`, `when(1, eq(0, 9), u8(1, shape))`, `m.bit(u16(2, heading))` (bits created in that order)
When `{"sid": 9, "shape": 4, "heading": 90}` and `{"sid": 1}` are packed
Then the bytes are `010901045a00` and `010100`, and both unpack to the same members

**AC-2: split-form bool**
Given `m = flag_byte()`, `Scheme(1, dict, m, m.bit(bool(0, on)))`
When `{"on": True}`, `{"on": False}` are packed and `0101` is unpacked
Then the bytes are `0101`, `0100`, and the row has `on is True`

**AC-3: misplaced bit fails construction**
Given a scheme listing `m.bit(u8(0, a))` before `m`, or a bit whose `m` is not in the scheme
When `Scheme(...)` is constructed
Then `ValueError` is raised

**AC-4: defaults do not leak into repeat lists**
Given the `Trail` dataclass scheme
When `0101000a000000140000001e00000028000000` is unpacked
Then `lat == [10, 30]` and `lon == [20, 40]`

**AC-5: shared class-level list is not mutated**
Given `class Trail2: lat = []; lon = []` with the same scheme
When the same bytes are unpacked twice
Then each row has `lat == [10, 30]` and `Trail2.lat == []`

**AC-6: times lists start empty**
Given a dataclass with `lat: object = 0` and `times(1, 0, i32(1, lat), i32(2, lon))` after `u8(0, n)`
When `01020a000000140000001e00000028000000` is unpacked
Then `lat == [10, 30]` and `lon == [20, 40]`

**AC-7: repeat with flags packs per item**
Given `u8(0, a)`, `repeat(1, flags(1, u8(1, v)))`
When `{"a": 1, "v": [1, None]}` is packed and unpacked
Then the bytes are `0101010100`, and the row has `v == [1]` (same as TS)

**AC-8: times with flags packs per item**
Given `u8(0, n)`, `times(1, 0, flags(1, u8(1, v)))`
When `{"n": 2, "v": [5, None]}` is packed
Then the bytes are `0102010500`

**AC-9: fixtures unchanged**
Given the golden row, the route fixture and the language-pair handoffs
When packed and unpacked
Then the bytes are unchanged

## Non-Functional Requirements

**Performance**
- The AC-10 Python loop stays ≤ 2 s.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-1 | `test_split_form_matches_typescript` | AC-1 rows | `010901045a00`, `010100` (today `ValueError`) |
| AC-2 | `test_split_form_bool` | AC-2 | `0101`/`0100`, `on is True` |
| AC-3 | `test_bit_before_flag_byte_is_scheme_error` | AC-3 | `ValueError` at construction |
| AC-4 | `test_repeat_ignores_row_defaults` | `Trail` | `[10, 30]` (today `[0, 10, 30]`) |
| AC-5 | `test_repeat_does_not_mutate_class_list` | `Trail2` ×2 | class list stays empty |
| AC-6 | `test_times_ignores_row_defaults` | AC-6 | `[10, 30]` |
| AC-7 | `test_repeat_with_flags_packs` | AC-7 | `0101010100` (today `AttributeError`) |
| AC-8 | `test_times_with_flags_per_item` | AC-8 | `0102010500` (today `TypeError`) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the AC-1 split-form vector, produced by TS | Python unpacks the TS bytes | same members | project AC-3 |
| AC-9 | `fixtures/golden.hex`, route fixture, handoffs `user`/`nested`/`session` | pack/unpack | unchanged | project AC-1/3 |
| — | `fixtures/hostile/` (task 01) `zero_progress_repeat` | unpack | still an error (task 02) | Reliability |

## Constraints

- ADR-001: Python only.
- Wire bytes unchanged for schemes that work today. New bytes appear only for schemes that could not pack before, and they equal the TS bytes.
- Scheme errors are `ValueError`.

## Risks & Mitigation

**Risk 1: Bit numbering by scheme position differs from `.bit()` call order**
- *Risk*: A caller who creates bits out of placement order would get different bit numbers than today (today nothing constructs, so there are no existing users).
- *Mitigation*: Follows C05 ("bit positions from field order"). Test with in-order creation only.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12: once split form builds, add Python to the `bitwhen` ring in `.github/workflows/language-pair.sh` (`u8 k`, split flag byte `m`, `when(eq(k,1), [m.bit(u8 v)])`, `{k:0, v:5}` → `010001`) | coordinator | open | Low |
| TS numbers split-form bits by `.bit()` call order (`fields.ts:131-138`), not by placement; same result for in-order creation. Align under C05 | coordinator / C05 | open | Low |
| Decision 2026-10-05 (loop 11 feature-assess U2): a split flag bit whose flag byte is not in its scope (byte inside a `when`, or outside the list/repeat/times round) is a scheme construction error in every package. Python gets the rule here; the other five are AZ-2108..AZ-2111 | user | open | Medium |
| A `times` with count 0 leaves the member as the row had it (TS leaves it absent); defaults then show as a scalar | coordinator | open | Low |
| Loop 12 review (AZ-2083 F2): the `_FlagBit` → `_Bool` unpack path is `pass`, so a split-form bool never unpacks `True`; and a flag byte listed without its bits (`Scheme(1, dict, fb)`) constructs and drops the bool, while listing both validates the bit's id twice. Fix all three here | coordinator | open | Medium |

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 2): AC-1 to AC-9 hold. One Included line is open and is the owner's call: bit numbers still follow `.bit()` call order, not scheme order, as in TypeScript, C# and Java (scheme-order numbering is AZ-2135; Python is not in its component list). A handle shared by two schemes fails at construction in Python ("flag byte: bit N is not in the scheme"), where TypeScript builds both. Bit ring `bitwhen` for Python: Python scheme and bytes verified (`010001`, `01010105`); the driver and `language-pair.sh` pair are added in loop 16 batch 3 (harness). Python now refuses a `repeat` or `times` inside a round at construction (owner decision 2026-10-06), and has round and slot limits (owner decision 2026-10-06, see the README Untrusted input section).
