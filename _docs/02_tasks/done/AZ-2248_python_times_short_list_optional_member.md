# Python accepts a short or empty `times` list for an optional member

**Task**: AZ-2248_python_times_short_list_optional_member
**Name**: Python `times` short or empty list for a member under `flags`
**Description**: Python pack reads an entry past the end of a `times` list as absent when the member is optional (a member under `flags`, at any depth, or the field of a flag bit), so `{c: 2, on: [True]}` packs `01 02 01 00` as in TypeScript and Java; a plain member or a member under `when` keeps raising `IndexError`, a longer list stays refused, Rust is unchanged.
**Complexity**: 2 points
**Dependencies**: AZ-2134_aligned_round_values (one list entry per round, `None` for a skipped round); AZ-2186_python_times_list_longer (a longer list is refused)
**Component**: python
**Tracker**: AZ-2248
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, round 2 (`_docs/loops/loop16/assessment16.md` X4), owner decision A on 2026-10-06. The README says a `times` list has "entry `i` for round `i`, `null` for a round that skipped the name" and refuses a longer list in every package; it says nothing about a list shorter than the count when the member may be absent. TypeScript and Java read a missing trailing entry as absent; Python raises a raw `IndexError` (`value[index]` in `_at_round`, `python/src/packbin/_pack.py`), although a row with no list at all packs. Probes on `35544ed` (Python 3.14.6, node 22.23, JDK 21 with `--release 17`, cargo 1.79; Python on a `git archive` export, TypeScript and Java on the same export). Scheme: `u8 c; times(1, 0, <shape>)`, count `c`:

| Shape in the round | Row | Python today | TypeScript | Java | Rust (map form) |
|---|---|---|---|---|---|
| `flags(bool on)` | `{c:2, on:[true]}` | `IndexError: list index out of range` | `01020100` | `01020100` | `PackError::Type("times at id 1: '1' is under a flags or when; give its values per round under '__times_1'")` (Rust's `bool` is an empty `group`, value `[1]`) |
| same | `{c:2, on:[]}` | `IndexError` | `01020000` | `01020000` | `01020000` |
| same | `{c:2}` (no `on`) | `01020000` | `01020000` | `01020000` | `01020000` |
| same | `{c:2, on:[true,null]}`, `[null,true]`, `[true,false]` | `01020100`, `01020001`, `01020100` | same | same | a Rust list holds no `null` (not probed) |
| `flags(u8 v)` | `{c:2, v:[5]}` | `IndexError` | `0102010500` | `0102010500` | the `__times_1` message above |
| same | `{c:2, v:[]}` | `IndexError` | `01020000` | `01020000` | `01020000` |
| `flags(u2 a, b)` | `{c:2, a:[1], b:[2]}` | `IndexError` | `0102010900` | `0102010900` | the `__times_1` message (names `'1'`) |
| `flags(flags(u8 v))` | `{c:2, v:[5]}` | `IndexError` | `010201010500` | `010201010500` | the `__times_1` message |
| `flags(group(u8 a, u8 b))` | `{c:2, a:[1], b:[2]}` | `IndexError` | `010201010200` | `010201010200` | the `__times_1` message |
| `m; m.bit(bool on)` (split bit) | `{c:2, on:[true]}` | `IndexError` | `01020100` | `01020100` | not probed |
| `m; m.bit(u8 v)` | `{c:2, v:[5]}` | `IndexError` | `0102010500` | `0102010500` | `0102010500` |
| `u8 k; m; when(k==1, m.bit(u8 v))` | `{c:2, k:[1,1], v:[5]}`, `v:[]` | `IndexError` | `01020101050100`, `010201000100` | same | not probed |
| `flags(u8 v, bool on)` | `{c:2, v:[5,6], on:[true]}` | `IndexError` | `010203050106` | same | not probed |
| plain `u8 x` | `{c:2, x:[1]}` and `x:[]` | `IndexError` | `RangeError: missing x` | `IllegalArgumentException: 1: expected int, got null` | `PackError::Missing("1")` |
| `u8 k; when(k==1, u8 v)` | `{c:2, k:[1,1], v:[7]}`, `{c:2, k:[1,0], v:[]}` | `IndexError` | `RangeError: missing v` | `IllegalArgumentException: 2: expected int, got null` | `{k:[1,0], v:[7]}` gives the `__times_1` message (names `'2'`), `{k:[1,0]}` gives `Missing("2")` |
| same | `{c:2, k:[1,0], v:[7]}` (round 1 skips the `when`) | `0102010700` | `0102010700` | `0102010700` | the `__times_1` message (names `'2'`) |
| `flags(u8 v)` | `{c:2, v:[5,6,7]}` | `ValueError: 1: 3 items, times count is 2` | `RangeError: v: 3 items, times count 2` | `IllegalArgumentException: 1: list has 3 entries for a count of 2` | the `__times_1` message (a member under `flags` is not checked for length) |

Further facts from the same probes:
- A group under `flags` and a `u2` under `flags` still need every slot or member of a set group. `{c:2, a:[1,2], b:[2]}` (round 1 sets `a`, lacks `b`): TypeScript `RangeError: missing b` for the group and `RangeError: b: expected 2-bit int` for the `u2`; Java `2: expected int, got null` and `2: expected 2-bit int`; Python today `IndexError`.
- A lone value for a member is shared by every round, and a `None` value is absent: `{c:2, v:5}` packs `010201050105` and `{c:2, v:None}` packs `01020000` in Python, TypeScript and Java, today and after.
- Unpack always returns full lists: `01020100` unpacks to `{c: 2, on: [True, None]}` and `0102010500` to `{c: 2, v: [5, None]}`, `01020000` to `{c: 2, v: [None, None]}`, and each row packs back to its packet in Python and TypeScript. A short list is therefore only a shorthand for trailing `None` entries; a row from unpack is never short.
- `repeat` differs already, and this ticket does not change it: with `repeat(u8 w, flags(u8 v))` and `{w:[1,2], v:[5]}` TypeScript and Java pack `010101050200` where Python raises `ValueError: repeat fields must have equal lengths`, and for `v:[]` Python raises `IndexError` where TypeScript and Java pack `0101000200`. That is the documented `repeat` rule (AZ-2186 Excluded, Python description §7) and is not part of this ticket (see Excluded).
- Rust keeps a map list only for the rounds that had a value, so it cannot tell which round a short list belongs to and refuses it for a member under `flags` or `when` (AZ-2189). An empty list or no list packs as clear bits. This is by design and stays.

## Outcome

- In `pack`, for a `times` round, an entry past the end of a member's list is read as absent when the member is optional: a member under `flags` at any depth (a direct child, a child of a nested `flags`, a member of a `group` under `flags`, a `u2` slot, a `bool`) or the field of a split flag bit (also when the bit stands under a `when`). Absent means the same as a `None` entry: the flag bit stays clear. So `{c: 2, on: [True]}` packs `01 02 01 00`, `{c: 2, v: [5]}` packs `01 02 01 05 00`, and `[]` packs like an absent list (`01 02 00 00`).
- A member that is not optional (a plain member, or a member under `when` that is not under `flags` or a flag bit) keeps raising `IndexError: list index out of range` for a short or empty list, and `TypeError: <id>: expected int, got NoneType` for a missing list, exactly as today (decision C15).
- A set group or `u2` with a missing sibling still fails, now with the same text the other packages give for a `None` entry (`ValueError: 2: expected 2-bit int`, `TypeError: 2: expected int, got NoneType`).
- A longer list stays refused (`ValueError: 1: 3 items, times count is 2`, AZ-2186). Unpack, the aligned rows of AZ-2134, `repeat`, Rust, and every packed byte of a row that packs today are unchanged.

## Scope

### Included
- The round read in `pack_nodes` for `times`: a way to know, for each member of a `times` body, whether it is optional (reached through `flags` or a flag bit), and to return `None` for an entry past the end of its list only for those members. The set of optional members can be found once at construction (as `leaves` is) or at pack time.
- Tests for the probes below, and the text that describes the rule (README `Times`, the Python description, its `tests.md`; sentences below).

### Excluded
- `repeat` (Python's equal-length rule and its `IndexError` for an empty list stay as documented): reported, not changed. If the owner wants `repeat` to follow `times`, it is a separate decision (Risks).
- A member under `when` that is not under `flags` or a flag bit: it keeps refusing a short list, as TypeScript and Java do.
- The raw `IndexError` label of a short list for a plain member (error labels, decision C15, AZ-2186 flagged concern).
- Rust (AZ-2189, by design), C# (held), C++.
- A tuple or other sequence given as a list (only `list` is a round list, as today), and the lone-value form.

## Acceptance Criteria

The Python column of the table above gives today's results; the "after" results come from a throwaway version of the change on a scratch copy (`_at_round` returning `None` past the end for the members found under `flags` or a flag bit; the 326 existing tests pass with it). The worker re-derives them from a real run.

**AC-1: A short or empty list for a `bool` under `flags`**
Given `u8(0, c)`, `times(1, 0, flags(1, bool(1, on)))` (accessors `lambda r: r["c"]`, `lambda r: r["on"]`; `bool` is `packbin.bool`, imported by name)
When `{c: 2, on: [True]}` and `{c: 2, on: []}` are packed
Then the bytes are `01020100` and `01020000` (today both raise `IndexError: list index out of range`); `{c: 2}` still packs `01020000`, `[True, None]` and `[True, False]` pack `01020100`, `[None, True]` packs `01020001`.

**AC-2: A short or empty list for a scalar under `flags`**
Given `u8(0, c)`, `times(1, 0, flags(1, u8(1, v)))`
When `{c: 2, v: [5]}`, `{c: 2, v: []}`, `{c: 2, v: [5, None]}`, `{c: 2, v: [5, 6]}`, `{c: 1, v: [5]}` and `{c: 0, v: []}` are packed
Then the bytes are `0102010500`, `01020000`, `0102010500`, `010201050106`, `01010105` and `0100` (the first two raise today).

**AC-3: Every optional shape**
Given `times(1, 0, ...)` over `flags(1, u2((1, a), (2, b)))`; `flags(1, flags(1, u8(1, v)))`; `flags(1, group(1, u8(1, a), u8(2, b)))`; `flags(1, u8(1, v), bool(2, on))`; `m` then `m.bit(bool(1, on))`; `m` then `m.bit(u8(1, v))`; and `u8(1, k)`, `m`, `when(2, eq(1, 1), m.bit(u8(2, v)))` (`m = flag_byte()`)
When they are packed with `{c: 2, a: [1], b: [2]}` and `{c: 2, a: [], b: []}`; `{c: 2, v: [5]}`; `{c: 2, a: [1], b: [2]}`; `{c: 2, v: [5], on: [True, False]}`, `{c: 2, v: [5, 6], on: [True]}` and `{c: 2, v: [], on: []}`; `{c: 2, on: [True]}`; `{c: 2, v: [5]}`; and `{c: 2, k: [1, 1], v: [5]}`, `{c: 2, k: [1, 1], v: []}`, `{c: 2, k: [0, 0], v: []}`
Then the bytes are `0102010900` and `01020000`; `010201010500`; `010201010200`; `0102030500`, `010203050106` and `01020000`; `01020100`; `0102010500`; and `01020101050100`, `010201000100`, `010200000000` (today every one of these rows raises `IndexError`).

**AC-4: A set group or `u2` that lacks a sibling still fails**
Given the `u2` and the group shapes of AC-3
When `{c: 2, a: [1, 2], b: [2]}` is packed
Then the `u2` raises `ValueError: 2: expected 2-bit int` and the group raises `TypeError: 2: expected int, got NoneType` (today `IndexError` for both; Java and TypeScript fail the same rows with their own labels).

**AC-5: A plain member and a member under `when` keep refusing**
Given `times(1, 0, u8(1, x))`, and `u8(1, k)`, `when(2, eq(1, 1), u8(2, v))`
When `{c: 2, x: [1]}` and `{c: 2, x: []}`, `{c: 2, k: [1, 1], v: [7]}` and `{c: 2, k: [1, 0], v: []}` are packed
Then each raises `IndexError: list index out of range`, as today. `{c: 2}` for the plain member raises `TypeError: 1: expected int, got NoneType`, `{c: 2, k: [1, 0]}` raises `TypeError: 2: expected int, got NoneType`, `{c: 2, x: [1, 2]}` packs `01020102`, `{c: 2, k: [1, 0], v: [7]}` packs `0102010700` and `{c: 2, k: [0, 0], v: []}` packs `01020000`, all as today.

**AC-6: A longer list stays refused**
Given the shapes of AC-1 and AC-2
When `{c: 2, on: [True, True, True]}` and `{c: 2, v: [5, 6, 7]}` are packed
Then each raises `ValueError: 1: 3 items, times count is 2`, as today.

**AC-7: Unpacked rows are full and pack back**
Given the shape of AC-1 (`bool` under `flags`) and the shape of AC-2 (`u8` under `flags`)
When `01020100` and `01020000` are unpacked with the first, `0102010500` and `010201050106` with the second, and each row is packed again
Then the rows are `{c: 2, on: [True, None]}`, `{c: 2, on: [None, None]}`, `{c: 2, v: [5, None]}` and `{c: 2, v: [5, 6]}`, and the repacked bytes equal the packets; a short list and the full list with `None` entries pack to the same bytes (this holds today and after).

**AC-8: Rows that pack today do not change; Python, TypeScript and Java agree**
Given 10 shapes (the eight optional shapes of AC-1 to AC-3 other than the split bit under `when`, a member under `when`, and a plain member) and 15,000 random rows (count 0 to 3, lists of 0 to 4 entries, `None`, lone values, absent members)
When each row is packed on `35544ed` and on the throwaway change
Then every row that packs on `35544ed` gives identical bytes (3,499 rows); every row that raises something other than `IndexError` raises the identical message (8,663 rows, among them 620 `IndexError` rows of the plain and `when` shapes, which are unchanged); of the 2,838 rows that raised `IndexError` on `35544ed` on a `flags` or flag-bit member, 2,452 now pack and 386 now raise the AC-4 errors. On the same 15,000 rows TypeScript and Java pack or refuse as the changed Python does and give the same bytes (5,951 pack, 9,049 refuse). The worker repeats this differential, and the three packages must still agree on the rows that pack.

## Non-Functional Requirements

**Compatibility**
- No wire change for any row that packs today. The only change is that rows which raised `IndexError` for an optional member now pack, or fail with the text a `None` entry gives. A forgotten trailing entry becomes a clear bit with no message (the trade-off the owner accepted).

**Reliability**
- A required member never gets a silent default: its short list raises exactly as before.

**Performance**
- No extra cost per round beyond one length check; the optional members are found once.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | `bool` under `flags`: short, empty, absent, `None` entries | the listed bytes (two raise today) | `python/tests/test_times_short_list.py` (new) |
| AC-2 | `u8` under `flags` | the six listed bytes | `python/tests/test_times_short_list.py` |
| AC-3 | `u2`, nested `flags`, group under `flags`, two members, split bit bool and `u8`, split bit under `when` | the listed bytes | `python/tests/test_times_short_list.py` |
| AC-4 | `u2` and group with a missing sibling | `ValueError`, `TypeError` with the listed text | `python/tests/test_times_short_list.py` |
| AC-5 | plain member and `when` member | `IndexError` and the listed results (extends `test_ac5_a_shorter_list_keeps_its_failure` of `test_times_longer_list.py`, which stays) | `python/tests/test_times_short_list.py` |
| AC-6 | longer lists | `ValueError: 1: 3 items, times count is 2` | `python/tests/test_times_short_list.py` |
| AC-7 | unpack then pack | rows and bytes as listed | `python/tests/test_times_short_list.py` |
| AC-8 | the differential and the existing suite | 326 tests pass; rows agree | `python/tests/` (whole suite) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-8 | `fixtures/golden.hex`, the route fixture of `test_borrowed_count.py`, `.github/workflows/drivers/handoff.py` (`boolflag`, `booltrue`, `bitwhen`) | pack | unchanged hex, 0 mismatched bytes | Compatibility |
| AC-8 | `language-pair.sh` rings, Python as producer and consumer | unchanged run | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Python only; no shared walker, no cross-package import. TypeScript and Java are the behaviour reference, not code to port.
- Files at or under 500 lines (`_pack.py` is 311, `_nodes.py` 426, `_unpack.py` 432). Keep the optional-member set where `leaves` is built or in a small helper.
- Error kind and label of existing errors unchanged (decision C15): `IndexError` for a short list of a required member, `TypeError: <id>: expected int, got NoneType` for a missing required value, `ValueError: <id>: <n> items, times count is <c>` for a longer list. The new texts of AC-4 are the ones a `None` entry already gives.
- The wire bytes of every row that packs and unpacks today are unchanged. No public API change, no change to unpack.
- "Optional" is decided by where the member stands in the scheme (under `flags` or a flag bit), not by its value or by the row, so a member reached both ways in one scheme follows each place's own rule.
- Probes (Python, TypeScript, Java, Rust) were run on `35544ed`; the Python "after" results and the differential come from a throwaway change on a scratch copy. The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A forgotten trailing entry becomes a clear bit with no message**
- *Risk*: `{c: 2, v: [5]}` packs a round with nothing in it where the caller meant two values.
- *Mitigation*: the owner chose this over refusing (X4 option A: it only turns an error into a result and breaks no working caller); TypeScript and Java already behave this way; the README sentence names it.

**Risk 2: `repeat` still differs**
- *Risk*: the same optional member in a `repeat` packs in TypeScript and Java and raises in Python (`repeat fields must have equal lengths`, or `IndexError` for `[]`).
- *Mitigation*: documented and held (AZ-2186 Excluded). STOP-and-report option for the owner: give `repeat` the same rule (`[]` and trailing entries absent for optional members; the equal-length rule would need an owner decision for required members). Not done here.

**Risk 3: The set of optional members is wrong for a shape not probed**
- *Risk*: a member under a `when` inside `flags`, or two members that share one list (two arms of a `when`), may be treated as optional by one place and required by another.
- *Mitigation*: the rule is per node, and a `when` under `flags` is not packed at all today (the held `when`-as-`flags`-member decision, assessment O11); AC-8's differential covers the nine shapes; any other shape found stops the worker for the owner.

## Owner decision (2026-10-06)

DECIDED, assessment round 2 X4 option A (the recommendation, "implement everything now"): accept a short or empty `times` list for an optional member in Python too, a missing trailing entry meaning absent, as TypeScript and Java do. A plain member still refuses a short list; a longer list stays refused (AZ-2186); Rust stays as it is by design. The decision covers the optional-under-`flags` members only; every other shape keeps today's behaviour and is reported (a member under `when`, `repeat`, the raw `IndexError` label). Reading the code and the probes: TypeScript, Java and the changed Python agree on every row of the differential.

## Documentation pass

Touch these when the code lands (the docs worker; the sentences are proposals).

- **README**, `Times` section, the paragraph that says "Pack refuses a list longer than the count in C# ..." (near line 1063), add after the longer-list sentences: "A list shorter than the count, or empty, is read for a member under `flags` or a flag bit as absent for the rounds it does not reach, as `null` is, in TypeScript, Java and Python: `u8 c; times(1, 0, flags(1, bool(1, on)))` with `{c: 2, on: [True]}` packs `01 02 01 00`, and `flags(1, u8(1, v))` with `{c: 2, v: [5]}` packs `01 02 01 05 00`. A forgotten entry is therefore a clear bit with no message. A plain member, and a member under a `when`, still need an entry for every round that reads them (TypeScript `missing x`, Java `1: expected int, got null`, Python `IndexError`). Rust does not take such a list for a member under `flags` (`times at id 1: '1' is under a flags or when; give its values per round under '__times_1'`)." Python upgrade paragraph (`Python changed in several places`), append: "A `times` list that is shorter than the count, or empty, now packs for a member under `flags` or a flag bit, a missing entry meaning absent (`{\"c\": 2, \"v\": [5]}` packs `01 02 01 05 00`); it raised `IndexError`. A plain member still raises `IndexError`."
- **`_docs/02_document/components/03_python_package/description.md`**: §2 `BinaryPacker.pack` row, keep the longer-list error and add "an entry past the end of a `times` list is absent for a member under `flags` or a flag bit (AZ-2248)"; §7 known limitation that reads "a `times` list shorter than its count raises a bare `IndexError`" becomes "... raises a bare `IndexError` for a member that is not under `flags` or a flag bit; for those it is absent (AZ-2248)"; §7 `Rounds` paragraph: add the rule and that `repeat` still needs equal lists.
- **`_docs/02_document/components/03_python_package/tests.md`**: heading "Loop 16 Tests (...)" add AZ-2248; a row `test_times_short_list`: "a short or empty `times` list for a `bool`, scalar, `u2`, nested `flags`, group and split-bit member under `flags` packs as TypeScript and Java do (`01020100`, `0102010500`); a plain member and a member under `when` keep `IndexError`; a longer list is refused; unpacked rows pack back (AZ-2248)" with file `python/tests/test_times_short_list.py`.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3), with AZ-2245 and AZ-2249 in the Python worker. A `times` list that is shorter than the count, or empty, is read as absent for the rounds it does not reach, for a member under `flags` at any depth or the field of a split flag bit, as in TypeScript and Java: `u8 c; times(1, 0, flags(1, bool(1, on)))` with `{c: 2, on: [True]}` packs `01 02 01 00`, `flags(1, u8(1, v))` with `{c: 2, v: [5]}` packs `01 02 01 05 00` (both raised `IndexError`). A plain member and a member under a `when` still raise the same `IndexError` (C15: no new label), a longer list stays refused (`ValueError: 1: 3 items, times count is 2`), unpack and `repeat` are unchanged.

Mechanism: `_nodes.py` a `_Times.optional` field and `_optional_leaves` (the ids of the leaves a flag bit can leave absent: reached through `flags` or a flag bit, also through `when` and groups below them), computed once at construction in `times()` and again in `_bind` (`_flag_scope.py`, +2); `_pack.py` (+10/-4) `_at_round(row, i, optional)` returns `None` past the end of a list only for those leaves.

Tests (`python/tests/test_times_short_list.py`, new, 225 lines, 21 tests; 11 fail at HEAD): AC-1 `test_ac1_a_short_or_empty_list_for_a_bool_under_flags_is_absent` (six rows); AC-2 the scalar twin (six rows); AC-3 seven tests (a `u2`, nested `flags`, a group under `flags`, two members, a split-bit bool, a split-bit scalar, a split bit under a `when`); AC-4 a set `u2` or group that lacks a sibling still fails (`ValueError: 2: expected 2-bit int`, `TypeError: 2: expected int, got NoneType`); AC-5 a plain member and a member under a `when` keep `IndexError` and their other results; AC-6 a longer list stays refused (bool, scalar); AC-7 unpacked rows are full and pack back; AC-8 `test_ac8_repeat_keeps_its_equal_length_rule_and_its_empty_list_failure`.

Evidence: 15,000 random rows over 11 shapes (the nine optional shapes including a split bit under a `when`, a `when` member and a plain member), HEAD against the change: 4,332 rows that packed at HEAD give identical bytes; 7,641 rows that raised something other than `IndexError` raise the identical message; 449 required-member `IndexError` rows are unchanged; of the 2,578 `IndexError` rows on optional shapes, 2,051 now pack and 338 raise the AC-4 texts (`TypeError` 201, `ValueError` 137), and the other 189 still raise `IndexError`, all of them the `bit_when` shape, whose plain member `k` has the short list. Against TypeScript (node 22, a scratch driver importing `typescript/src` read-only) on the same 15,000 rows: 6,383 pack with identical bytes and 8,617 are refused in both, zero disagreements. Java was not cross-run by the worker; the docs pass probed it on the working tree: bool short `01020100`, `u8` short `0102010500`, a plain member `1: expected int, got null`, as the README says. Rust stays as it is by design: every list form under `flags` gives `times at id 1: '1' is under a flags or when; give its values per round under '__times_1'`, a plain member `Missing("1")`.

Open and discovered: `repeat` keeps its rule in Python: equal-length lists, and `IndexError` for `[]` (pinned by a test), while TypeScript and Java pack these rows (`repeat(u8 w, flags(u8 v))` with `v:[5]` and `w:[1,2]` packs `010101050200` there and raises `ValueError: repeat fields must have equal lengths` here): the spec's STOP item, the owner decides whether `repeat` follows `times`. A `when` that is a direct member of `flags` is never packed in Python (held decision O11); `_optional_leaves` passes optionality through `when` and `group`, so those leaves would become optional if that changes, with no effect today. The ticket text "anchored group named like its own child" and similar TypeScript wording have no Python counterpart (a group is flat). Docs: README patch (the `times` section holds the four packages' behavior for a short list in one place, plus the Python upgrade paragraph), Python description, `tests.md` and `01_solution/schema.md`.
