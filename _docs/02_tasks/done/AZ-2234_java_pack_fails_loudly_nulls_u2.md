# Java pack fails loudly for a missing nested row, a null group element and `u2` in a round

**Task**: AZ-2234_java_pack_fails_loudly_nulls_u2
**Name**: Java pack: missing nested rows and null group elements throw, `u2` honours the round item
**Description**: Pack throws `IllegalArgumentException` instead of writing bytes its own unpack reads differently: a nested-row member that is null or absent, and a null element of a list or dict of nested-row groups, throw outside `flags`; a `u2` inside a `repeat` or `times` round packs the item of that round instead of failing with `expected 2-bit int`.
**Complexity**: 3 points
**Dependencies**: AZ-2101_java_typed_nested_rows (nested rows and their factory), AZ-2127_java_nested_rounds (rounds and per-round items), AZ-2190_java_pack_integer_float_strict (every pack refusal is an `IllegalArgumentException`)
**Component**: java
**Tracker**: AZ-2234
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, Q4 (c), (d), (e), owner answer of 2026-10-06: "take all recommendations, implement everything now" (Q4 option A, except the inner `repeat` case, which stays documented). Batch 2 review JA-F3 and the batch 2 report row 7 name the first two.

All probes were run on Java at HEAD `2eb9875` (the working tree is identical for `java/`), JDK 21, on a scratch copy of `java/` and `fixtures/`. Rows are `Map` rows unless marked typed; `g` is a nested row `Packbin.group(Access.get("g"), Access.set("g"), u8 0 v)`; a list or dict element group is `Packbin.group(Access.identity(), Access.ignore(), u8 0 v)`. Nested rows number their ids from 0.

### (1) and (2) are one defect: `Walker.packGroup` returns when the member is null

The ticket lists a null nested member (1) and an absent nested row (2) separately. In the code they are the same case: `Walker.packGroup` reads the member through its accessor and `if (target == null) return;`. A `Map` row with no key and a row with the key set to `null` both give null; a typed row's field is null. Unpack always creates the member and reads every field of the nested row (`Walker.unpackGroup`), so no byte string packed from a null member can read back as that row.

- Probe 1, `[group(g, u8 0 v), u8 0 tail]`: `{g:{v:3}, tail:7}` packs `01 03 07` (reads back). `{g:null, tail:7}` and `{tail:7}` both pack `01 07`; unpack of `01 07` gives `ShortPacket(field "0", needed 1, left 0)`: `v` takes the 7, `tail` has nothing. Typed row (`Outer { Inner inner; Integer tail; }`, factory `Inner::new`): `inner == null, tail == 7` packs `01 07`.
- Probe 2, nested rows inside nested rows: `[group(g1, group(g2, u8 0 v), u8 0 w)]` with `{g1:{w:2}}` packs `01 02` and `{}` packs `01`; unpack gives `ShortPacket(field "0", needed 1, left 0)` for both.
- Probe 3, under `when`: `[u8 0 k, when(1, eq(0, 1), g)]` with `{k:1}` and `{k:1, g:null}` packs `01 01`, unpack `ShortPacket(field "0", needed 1, left 0)`. With `{k:2}` it packs `01 02` and reads back.
- Probe 4, rounds: `[repeat(0, u8 0 a, g)]`. `{a:[1,2], g:[{v:5}, null]}` and `{a:[1,2], g:[{v:5}]}` pack `01 01 05 02`, unpack `ShortPacket(field "0", needed 1, left 0)`. `{a:[1,2]}` packs `01 01 02` and unpack returns OK with a different row, `{a:[1], g:[{v:2}]}`. `{}` packs `01`. `{a:[1,2], g:[{v:5},{v:6}]}` packs `01 01 05 02 06`. `[u8 0 n, times(1, 0, g)]`: `{n:2, g:[{v:5}, null]}` and `{n:2, g:[{v:5}]}` pack `01 02 05`, `{n:2}` packs `01 02` (all three unpack to `ShortPacket(field "0", needed 1, left 0)`); `{n:0}` packs `01 00`; `{n:2, g:[{v:5},{v:6}]}` packs `01 02 05 06`.
- Probe 5, list and dict of group elements: `[list(l, elem)]`: `{l:[{v:1}, null, {v:2}]}` packs `01 03 00 01 02` (count 3, two elements; unpack `ShortPacket(field "0", needed 1, left 0)`); `{l:[null]}` packs `01 01 00`; `{l:[{v:1},{v:2}]}` packs `01 02 00 01 02`; `{l:[]}` packs `01 00 00`. `[dict(d, elem)]`: `{d:{a:{v:1}, b:null}}` packs `01 02 00 01 00 61 01 01 00 62` (key `b` has no element; unpack `ShortPacket(field "0", needed 1, left 0)`). Typed `List<Item>` with a factory element group, `[item, null, item]`: packs `01 03 00 01 01`.
- Elements that already fail, unchanged: a list of `u8` `[1, null, 2]` throws `0: expected int, got null`; a list of lists `[[1], null]` throws `list: expected list`; a list of anchored groups or of `flags` elements with a null item throws `expected map` (Map accessors).
- Under `flags` or a flag-byte bit a null nested member clears the bit and nothing is written: `[flags(0, g)]` with `{}` packs `01 00` and with `{g:{v:4}}` packs `01 01 04`; `[m, m.bit(g)]` the same.

### (3) `u2` inside a round

`Walker.packField` calls `VarFields.packU2(field, row, sink, seen)` with no round lookup, so `packU2` reads each slot with `slot.get.get(row)` (the whole list) while every other value field and the presence check (`Walker.childOn`, `anySlotPresent`) read the round's item. A `u2` slot is a round value (`Rounds.collect` lists its slots), and unpack gives one list entry per round.
- Probe 6: `[repeat(0, u2(slot 0 a, slot 1 b))]` with `{a:[1,2], b:[3,0]}` throws `IllegalArgumentException: 0: expected 2-bit int`; `{a:[1], b:[2]}` throws the same. Unpack of `01 0e 09` returns `{a:[2,1], b:[3,2]}`, and packing that row back throws the same error. `[u8 0 n, times(1, 0, u2(slot 1 a, slot 2 b))]` with `{n:2, a:[1,2], b:[3,0]}` throws `1: expected 2-bit int`. Only a lone value `{a:1, b:2}` packs (`01 09`, one round).
- Probe 7, presence and `packU2` disagree: `[repeat(0, flags(0, u2(slot 0 a, slot 1 b)))]` with `{a:[1,null], b:[2,null]}` sets the bit for round 0 by the round item, then `packU2` throws `0: expected 2-bit int`; `{a:[null], b:[null]}` packs `01 00` (bit clear). A flag-byte bit holding the `u2` in a round throws the same; a `when` that tests a slot after the `u2` (`[repeat(0, u2(slot 0 a, slot 1 b), when(2, eq(1, 2), u8 2 w))]`) with `{a:[1,1], b:[2,0], w:[9,null]}` throws `0: expected 2-bit int` too (code reading: `packU2` also stores the whole list under the slot id in `seen`, so the condition would test a list).
- A `u2` outside a round: `{a:1, b:2}` packs `01 09`; `{a:1}` and `{a:1, b:4}` throw `1: expected 2-bit int`; inside a nested row `{g:{a:1, b:2}}` packs `01 09`; a nested row with a `u2` in a round, `{g:[{a:1,b:2},{a:3,b:0}]}`, packs `01 09 03` (a nested row has its own `take`).

### Scratch trial and differential

A trial change (three edits: `packGroup` throws `missing group`; `Containers.packList` and `packDict` refuse a null nested-row element; `packU2` takes the round lookup) passes `bash java/test.sh` with no test changed, and gives the "New" results of the ACs below. A differential of 5,000 random Map schemes (u8, u2, nested rows, `when`, `flags`, `repeat` as the last field, `times`, lists and dicts of leaf, group and list elements; 4 random rows each, with null items, absent members and short lists), HEAD against the trial, ran 4,835 valid schemes and 19,340 rows. Both pack, bytes differ: 0. Both pack, same bytes: 8,730. HEAD packs and the trial throws: 2,363, of which 2,113 are bytes whose unpack fails and 250 are bytes that unpack without an error to a different row (Probe 4, `{a:[1,2]}`). Both throw: 5,987 with the same message and 1,514 with another one (the new error is met first in pack order, or the `u2` error that hid a later one is gone). HEAD throws and the trial packs: 746 (742 are the `u2` rounds and read back; 4 pack a `times` whose body reads nothing, which unpack refuses as an empty round, as at HEAD). Every row that packs and unpacks with the trial packs back to the same bytes: 9,267 rows, 0 differ, 0 throw (HEAD: 8,704 same, 70 differ, 1 throws).

## Outcome

- Pack throws `IllegalArgumentException("missing group")` when the nested-row member (accessor `group`) of a row that is being written is null or absent: at the top level, below a `when` that holds, inside an anchored group, inside another nested row, and for every round index below the round count of a `repeat` or `times` (a list shorter than the count, an absent list while another member of the round has rounds, a null item).
- Pack throws `IllegalArgumentException("missing list element I")` (I = zero-based index) for a null element of a list whose element is a nested-row group, and `IllegalArgumentException("missing dict element \"key\"")` for a null value of a dict of such elements. The first null in list order, or in the sorted key order pack writes, is named.
- Under `flags` and under a flag-byte bit a null nested member keeps clearing the bit, and nothing is checked or written (unchanged).
- `packU2` packs the item of the current round when it is called inside a `repeat` or `times` round (a lone value is the item of every round, as for other fields), stores that item under the slot id for later `when` conditions and counts, and keeps its errors (`N: expected 2-bit int` for a missing, non-integer or out-of-range slot).
- Rows that packed readable bytes do not change; errors that were already thrown keep their kind and message. A row with two defects reports the first one in pack order, which can now be the new one.

## Scope

### Included
- `Walker.packGroup` (null target), `Walker.packField` (`U2` passes the round lookup), `VarFields.packU2`, `Containers.packList` and `packDict` (null element of a nested-row group).
- Pack through `PackSession.pack` (it calls `BinaryPacker.pack`, so it throws the same).
- New tests; the Javadoc sentence of `Packbin.group(get, set, ...)` is unchanged. README Java section and upgrade note (docs worker): null nested members and elements now throw; `u2` in a round packs.

### Excluded
- The inner `repeat` or `times` reached by one round of an enclosing round with later rounds or fields after it (Q4 (a)): stays documented (README, "a repeat has no end marker"), as for a top-level `repeat`.
- A flag byte outside a nested row with its bit inside (AZ-2233) and typed element groups (AZ-2235).
- Null elements of other kinds: a leaf, a nested list or dict, an anchored group, a `when` or a `flags` element already throw (`0: expected int, got null`, `list: expected list`, `expected map`); their messages are unchanged (error kind and label of existing errors, decision C15).
- A null `when`, `times` or `repeat` member under `flags`, which the owner holds for the C# loop (O2).
- Unpack, the hostile `pack` stage (AZ-2194) and other packages.

## Acceptance Criteria

**AC-1: A null or absent nested-row member throws (Probes 1 and 2)**
Given `[group(g, u8 0 v), u8 0 tail]`; `[group(g1, group(g2, u8 0 v), u8 0 w)]`; and the typed `Outer` scheme with `Inner::new`
When `{g:null, tail:7}`, `{tail:7}`, `{g1:{w:2}}`, `{}` and `Outer{inner null, tail 7}` are packed
Then each throws `IllegalArgumentException` with the message `missing group`, and no bytes are returned (HEAD packs `01 07`, `01 07`, `01 02`, `01`, `01 07`). `{g:{v:3}, tail:7}` still packs `01 03 07` (typed row too) and unpacks back.

**AC-2: Below a `when`, a null member throws only when the `when` holds (Probe 3)**
Given `[u8 0 k, when(1, eq(0, 1), g)]`
When `{k:1}` and `{k:1, g:null}` are packed, and then `{k:2}`
Then the first two throw `missing group` (HEAD `01 01`); `{k:2}` packs `01 02` and unpacks back.

**AC-3: In a round, a nested row missing for any round below the count throws (Probe 4)**
Given `[repeat(0, u8 0 a, g)]` and `[u8 0 n, times(1, 0, g)]`
When `{a:[1,2], g:[{v:5}, null]}`, `{a:[1,2], g:[{v:5}]}`, `{a:[1,2]}` and `{n:2, g:[{v:5}, null]}`, `{n:2, g:[{v:5}]}`, `{n:2}` are packed
Then each throws `missing group` (HEAD `01 01 05 02`, `01 01 05 02`, `01 01 02` and `01 02 05`, `01 02 05`, `01 02`). Unchanged: `{}` for the repeat packs `01`; `{n:0}` packs `01 00`; `{a:[1,2], g:[{v:5},{v:6}]}` packs `01 01 05 02 06`; `{n:2, g:[{v:5},{v:6}]}` packs `01 02 05 06`; `{a:[1], g:{v:5}}` (a lone map) packs `01 01 05`.

**AC-4: A row read by unpack still packs back**
Given `[repeat(0, u8 0 k, when(1, eq(0, 1), g))]` and `01 01 09 02` unpacked, which gives `{k:[1,2], g:[{v:9}, null]}`
When the row is packed again
Then the bytes are `01 01 09 02` (the null entry sits in a round where the `when` does not hold, so it is not written), at HEAD and after.

**AC-5: A null element of a list or dict of nested-row groups throws (Probe 5)**
Given `[list(l, elem)]` and `[dict(d, elem)]` with `elem` the group `u8 0 v`, and the typed `List<Item>` scheme with a factory element group
When `{l:[{v:1}, null, {v:2}]}`, `{l:[null]}`, `{d:{a:{v:1}, b:null}}` and the typed `[item, null, item]` are packed
Then they throw `IllegalArgumentException` `missing list element 1`, `missing list element 0`, `missing dict element "b"` and `missing list element 1` (HEAD packs `01 03 00 01 02`, `01 01 00`, `01 02 00 01 00 61 01 01 00 62`, `01 03 00 01 01`). `{l:[{v:1},{v:2}]}` still packs `01 02 00 01 02` and `{l:[]}` packs `01 00 00`. The already-failing elements keep their messages: `0: expected int, got null` (list of `u8`), `list: expected list` (list of lists), `expected map` (anchored group and `flags` elements).

**AC-6: Under `flags` or a flag-byte bit a null member clears the bit (unchanged)**
Given `[flags(0, g)]` and `[m, m.bit(g)]`
When `{}` and `{g:{v:4}}` are packed
Then `01 00` and `01 01 04` for both, as at HEAD.

**AC-7: `u2` in a round packs the round item (Probe 6)**
Given `[repeat(0, u2(slot 0 a, slot 1 b))]` and `[u8 0 n, times(1, 0, u2(slot 1 a, slot 2 b))]`
When `{a:[1,2], b:[3,0]}`, `{a:[1], b:[2]}`, `{a:1, b:2}` and `{n:2, a:[1,2], b:[3,0]}` are packed, and `01 0e 09` is unpacked and the row packed again
Then the bytes are `01 0d 02`, `01 09`, `01 09` and `01 02 0d 02`; the unpacked row is `{a:[2,1], b:[3,2]}` and packs back to `01 0e 09` (HEAD throws `0: expected 2-bit int` for the first, second and the repack, and `1: expected 2-bit int` for the `times`; the lone value packed `01 09` at HEAD too).

**AC-8: The presence check and the packed `u2` agree in a round (Probe 7)**
Given `[repeat(0, flags(0, u2(slot 0 a, slot 1 b)))]`, `[repeat(0, m, m.bit(u2(slot 0 a, slot 1 b)))]` with a flag byte `m`, and `[repeat(0, u2(slot 0 a, slot 1 b), when(2, eq(1, 2), u8 2 w))]`
When `{a:[1,null], b:[2,null]}` (both flag forms), `{a:[null], b:[null]}` (both flag forms), `{a:[1,null], b:[2,3]}` (both flag forms) and `{a:[1,1], b:[2,0], w:[9,null]}` are packed
Then the bytes are `01 01 09 00` for both flag forms (and `01 01 09 00` unpacks to `{a:[1,null], b:[2,null]}`), `01 00` for the clear bit, `0: expected 2-bit int` thrown for the partly present round (slot `a` is null in round 1 while `b` is present, as a single `u2` with one slot missing at the top level), and `01 09 09 01` for the `when` (the condition sees `b` of the round: only round 0 writes `w`). At HEAD the first, third and fourth throw `0: expected 2-bit int`.

**AC-9: `u2` outside rounds and everything else is unchanged**
Given `[u2(slot 0 a, slot 1 b)]`, `[g(u2)]`, `[repeat(0, g(u2))]`, the golden fixture, the hostile fixtures, `java/test.sh` and `language-pair.sh`
When `{a:1, b:2}`, `{a:1}`, `{a:1, b:4}`, `{g:{a:1,b:2}}` and `{g:[{a:1,b:2},{a:3,b:0}]}` are packed
Then `01 09`, `1: expected 2-bit int`, `1: expected 2-bit int`, `01 09`, `01 09 03`; all suites and fixtures are unchanged, and a differential run of random schemes and rows against HEAD finds no scheme and row that packs at both with different bytes (every difference is a row that HEAD wrote unreadable or threw on).

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed readable bytes are unchanged. Public API unchanged; the only change is which rows pack.
- Error kind is `IllegalArgumentException`; existing messages are unchanged.

**Reliability**
- Pack returns bytes that hold every nested row and every element it was given, or throws; it never drops one. Unpack of a packed row, packed again, gives the same bytes (observed: 9,267 of 9,267 rows).

**Performance**
- One null check per nested row, per list element and per dict value; the `nfrRoundTripsWithinOneSecond` test still passes.

## Unit Tests

AC-1 to AC-5 and AC-7 to AC-8 must fail first.

| AC Ref | What to Test | Required Outcome | Test class |
|--------|-------------|-----------------|------------|
| AC-1 | `{g:null}`, absent, nested twice, typed `Outer` | `missing group`; the present row packs `01 03 07` | `MissingNestedValueTest` (new, registered in `PackbinTest.main`) |
| AC-2 | `when` holds with null member; `when` not held | throws; `01 02` | `MissingNestedValueTest` |
| AC-3 | repeat and times, null item, short list, absent list, valid rows | throws; bytes as listed | `MissingNestedValueTest` |
| AC-4 | unpack `01 01 09 02`, repack | `01 01 09 02` | `MissingNestedValueTest` |
| AC-5 | list, dict, typed list; other element kinds | the three messages; old messages unchanged | `MissingNestedValueTest` |
| AC-6 | `flags` and flag-byte bit with a null member | `01 00`, `01 01 04` | `FlagPresenceTest` (it already holds the presence-under-flags cases) |
| AC-7 | `u2` in repeat and times; unpack then repack | bytes as listed | `RepeatRoundTest` |
| AC-8 | `u2` under `flags` and a flag-byte bit in a round; `when` after a `u2` | bytes as listed; partial round throws | `RepeatRoundTest` |
| AC-9 | `u2` outside rounds; fixtures and the full suite | unchanged | `PackStrictTest` (the `u2` rows), `java/test.sh` |

`RepeatRoundTest` is 157 lines, `FlagPresenceTest` 101, `PackStrictTest` 280: each stays under 500 with its additions.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-9 | `fixtures/golden.hex`, `fixtures/hostile/*` | Java pack and unpack | identical to HEAD | Compatibility |
| AC-9 | `language-pair.sh` rings that include Java | producer and consumer | 0 mismatched bytes | Compatibility |
| AC-1, AC-5 | a session scheme with a nested row | `PackSession.pack` with a null member | throws `missing group`, no frame | Reliability |

## Constraints

- ADR-001: Java only, no shared walker, no cross-package import.
- Files at or under 500 lines (`Walker.java` is 432, `Containers.java` 195, `VarFields.java` 336).
- Error kind and label of existing errors unchanged (decision C15); the new messages follow the `member: reason` / `missing ...` style (`missing field N` for scalars, `group` as `Rounds.member` names a nested row).
- Pack errors are `IllegalArgumentException`; no new exception type; no public API change.
- Bytes in the ACs were reproduced on Java at HEAD and in a scratch trial of the change; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller packs rows whose nested row is optional**
- *Risk*: a scheme with a plain nested-row member and rows that leave it out packed a stream that unpack could not read (Probe 1). It now throws.
- *Mitigation*: the message names the member kind; an optional nested row belongs under `flags` or a flag-byte bit, which clear the bit when it is null (AC-6); README upgrade note (docs worker).

**Risk 2: A row that an unpack produced does not pack again**
- *Risk*: a null round entry for a nested row would throw.
- *Mitigation*: unpack gives a null entry only where a `when` or a flag bit skipped the nested row, and neither writes it (AC-4); the differential shows 0 of 9,267 rows break.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket gives the message form `missing field N`, as scalars have. A nested row has no field id (its id is -1, ids inside restart at 0), so this spec uses `missing group` (the label `Rounds.member` already gives a nested row), `missing list element I` and `missing dict element "key"`. The owner may prefer other wording; the tests pin the text | owner | open | Low |
| Ticket items (1) and (2) are the same code path (`packGroup` returns on null); one rule and one set of ACs cover both | implementer | resolved here | Low |

## Owner decision (2026-10-06)

DECIDED, assessment 16 Q4 (c), (d), (e), option A, recommendation taken ("take all recommendations, implement everything now"): pack throws `IllegalArgumentException` naming the missing value for a null or absent nested-row member and a null list or dict element outside `flags`, and `packU2` honours the round item; under `flags` a null member keeps clearing the bit; rows that packed readable bytes do not change (differential against HEAD). The inner `repeat` case (Q4 (a)) stays documented.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2). Java pack fails loudly where it wrote bytes that unpack read as a different row. `Walker.packGroup` throws `IllegalArgumentException("missing group")` for a nested-row member that is `null` or absent, wherever pack reaches it outside `flags` and a flag-byte bit (also for each round of a `repeat` or `times` that has no row for it); `Containers.packList` and `packDict` throw `missing list element I` and `missing dict element "key"` for a `null` element of a list or dict of nested-row groups; `Walker.packField` passes `take` to `VarFields.packU2`, so a `u2` in a `repeat` or `times` round packs the item of each round (`{a:[1,2], b:[3,0]}` gives `01 0d 02`; it threw `0: expected 2-bit int`). Under `flags` or a flag-byte bit a `null` member still clears the bit and writes nothing. `PackSession.pack` throws before the send counter moves.

Tests: new `MissingNestedValueTest` (241 lines, registered in `PackbinTest`): `ac1NullOrAbsentMemberThrows`, `ac1TypedMemberThrows` (AC-1); `ac2UnderAWhenOnlyWhenItHolds`; `ac3EveryRoundBelowTheCountNeedsItsRow`; `ac4ARowReadByUnpackStillPacksBack`; `ac5ListElements`, `ac5DictElements`, `ac5TypedListElement`, `ac5OtherElementKindsKeepTheirMessages`, `sessionPackThrowsAndSendsNoFrame` (AC-5); plus `FlagPresenceTest.az2234Ac6NullNestedRowClearsTheBit`, `RepeatRoundTest.az2234Ac7U2PacksTheRoundItem` and `az2234Ac8PresenceAndU2AgreeInARound`, `PackStrictTest.az2234Ac9U2OutsideRoundsIsUnchanged`. Written first: 42 checks failed at HEAD (AC-4, AC-6 and AC-9 pin unchanged behavior and pass). The Java count of `expectEq`/`expectTrue` calls across the three specs is 1324 (HEAD), 1494 and, with the review test, 1501.

Evidence: every HEAD byte string and error of the spec's probes 1 to 7 reproduced (`01 07`, `01 01 05 02`, `01 03 00 01 02`, `0: expected 2-bit int`); differential of 280,000 schemes, about 1.5 M rows: 749,506 rows with identical bytes where both pack; mutants killed (`packGroup` returning on a null member, `packU2` ignoring `take`, `seen` given the whole list, the container checks removed, the send counter moved before the pack: four session checks fail).

Review finding F4 (low): rows that read back modulo nulls or lossily at HEAD now throw `missing group`: `repeat(g)` with `{g: [null, null]}` (wrote `01`), `{g: [{v: 1}, null]}` (wrote `01 01`, read back as `[{v: 1}]`), and an absent nested row whose body writes 0 bytes (`group(g, repeat(...))` with `{}` wrote `01`). Spec-literal ("null item" below the round count); documented, not changed: the README upgrade note lists the shapes and the asymmetry (`{}`, `{g: null}` and `{g: []}` for a `repeat` of the row still pack `01`, because no round is reached). In the differential 194 of about 1.54 M rows that HEAD read now throw, all of this kind.

Open (Low, owner): the ticket text said `missing field N`; a nested row has no field id, so the messages are `missing group`, `missing list element I` and `missing dict element "key"`, pinned by the tests. `missing group` carries no round index or path.
