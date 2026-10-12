# Loop 21 reference: slot width of a round (AZ-2382), empty round body (AZ-2390), short optional list (AZ-2383), probes (AZ-2384, AZ-2386, AZ-2387), round scope cost (AZ-2391)

TypeScript is the reference package (problem D1). Every row below was produced by `typescript/src` on `dev`
(Node v22.23.0, darwin) and is pinned by these test files in `typescript/tests/`:
`round-slot-width.test.ts` (AZ-2382), `empty-round-body.test.ts` (AZ-2390), `repeat-short-optional.test.ts`
(AZ-2383), `round-scope-cost.test.ts` (AZ-2391), `loop21-parity-probes.test.ts` (AZ-2384, AZ-2386, AZ-2387).
Builder syntax is TypeScript (`typescript/src/index.ts`); hex is the whole packet, type byte `01` included.
Each package keeps its own error type (TypeScript `RangeError`, Python `ValueError`, Java
`IllegalArgumentException`, C# `ArgumentException`, Rust `PackError`). Copy the message text unless the
package's error style forbids it; then report the difference.

## 1. AZ-2382: the slot rule (no code change: TypeScript already had it)

TypeScript pack and unpack already charged the same width (`roundNames(fields, false).size`, in
`typescript/src/rounds.ts`; unpack `refuseRound` in `walker.ts`). Probing ten shapes found no pack/unpack
difference, so the rule was confirmed, not changed.

**Width W of a round** = the number of **distinct** names a round can hold:

- counted, 1 each: every value field's own name (ints, floats, `bytes`, `bool`, `utf8`, `sized`, `bits`,
  `packed`), a `list` name, a `dict` name, **each `u2` slot name**, an **empty** group's name;
- counted from inside: the members of a `when` (whether its condition holds or not in the round), of
  `flags`, of a flag bit, and of a group, at any depth;
- **not counted**: a non-empty group's own name (only its members), `flags` itself, the combined `flags` byte,
  a split `flagByte("m")` name, the anchors of `when`, `repeat`, `times`;
- **a name that appears twice in the round is one slot** (two `when` branches that both declare `k`);
- a list or dict is one slot however many items one round gives it.

**When**: as each round starts, before any byte of that round. With `slots` the total charged so far in this
pack call: `slots + W > maxSlots` refuses the round, otherwise `slots += W` and the round is written. A round
is all or nothing, so "one over the limit" is the next whole round: it would hold `maxSlots + W` slots.

**Scope**: one counter per pack (or unpack) call, shared by every `repeat` and `times` at any depth (top
level, `flags`, groups, `when`, split bits, list and dict elements). Message:
`{member}: the rounds would hold {slots + W} slots, above the limit of {maxSlots} slots`; member = the first
name the round holds in declaration order, depth-first, a group's own name before its members (pack's
`roundNames(fields, true)`; `{repeat|times} {anchor}` if it holds none). Unpack refuses at the same round
index and names the first name unpack lists (`firstName`), see the naming note below.

### Rows

Each row is `new Scheme(1, [repeat(0, BODY)], { maxSlots: 2W })`; rows with 2 rounds pack exactly at
`maxSlots`; the 3rd round would hold `3W` slots. "Unpack" is `unpack(hex of the 3-round packet, the 2W
scheme)`, the packet written by the same scheme with `maxSlots: 3W` (the 3-round hex column).

| # | Shape | BODY (TypeScript) | Row, 2 rounds | W | Hex at `maxSlots` = 2W | 3rd round, `maxSlots` = 2W | 3-round hex (`maxSlots` 3W) | Unpack of the 3-round packet at 2W |
|---|---|---|---|---|---|---|---|---|
| 1 | empty group, flag byte | `u8(0,a), flags(1, [group(g, [])])` | `a [1,2]`, `g [true, undefined]` | 2 (`a`, `g`) | `0101010200` | `a: the rounds would hold 6 slots, above the limit of 4 slots` | `01010102000301` | `{ok:false, field:"a", needed:0, left:2}` |
| 2 | duplicate leaf names | `u8(0,m), when(1, eq(0,1), [u8(1,k)]), when(2, eq(0,2), [u8(2,k)])` | `m [1,2]`, `k [7,8]` | 2 (`m`, `k`: `k` once) | `0101070208` | `m: the rounds would hold 6 slots, above the limit of 4 slots` | `01010702080109` | `field:"m", left:2` |
| 3 | combined `flags` (member names; the byte is no name) | `flags(0, [bool(0,on), u8(1,v)])` | `on [true,true]`, `v [5,6]` | 2 (`on`, `v`) | `0103050306` | `on: the rounds would hold 6 slots, above the limit of 4 slots` | `01030503060307` | `field:"on", left:2` |
| 4 | split bits + flag byte `m` | `fb=flagByte("m"); fb, fb.bit(u8(0,a)), fb.bit(u8(1,b))` | `a [1,2]`, `b [4,5]` | 2 (`a`, `b`; `m` is not a slot) | `01030104030205` | `a: the rounds would hold 6 slots, above the limit of 4 slots` | `01030104030205030306` | `field:"m", needed:0, left:3` |
| 5 | `when` clear in every round | `u8(0,m), when(1, eq(0,1), [u8(1,k)])` | `m [0,0]` | 2 (`m`, `k` charged although `k` is never written) | `010000` | `m: the rounds would hold 6 slots, above the limit of 4 slots` | `01000000` | `field:"m", left:1` |
| 6 | nested anchored groups | `u8(0,a), group(1,g,[u8(1,b), group(2,h,[u8(2,c)])])` | `a [1,2]`, `b [4,5]`, `c [7,8]` | 3 (`a`, `b`, `c`; `g`, `h` are not slots) | `01010407020508` | `a: the rounds would hold 9 slots, above the limit of 6 slots` | `01010407020508030609` | `field:"a", left:3` |
| 7 | unanchored group | `u8(0,a), group(g, [u8(0,b)])` | `a [1,2]`, `b [4,5]` | 2 (`a`, `b`) | `0101040205` | `a: the rounds would hold 6 slots, above the limit of 4 slots` | `01010402050306` | `field:"a", left:2` |
| 8 | `u2` slots | `u8(0,a), u2(1,p, 2,q, 3,r)` | `a [1,2]`, `p [1,1]`, `q [2,2]`, `r [3,3]` | 4 (`a` + 3 slot names) | `0101390239` | `a: the rounds would hold 12 slots, above the limit of 8 slots` | `01013902390339` | `field:"a", left:2` |
| 9 | `list` / `dict` names | `u8(0,n), list(l, u8 e), dict(d, u8 e)` | `n [1,2]`, `l [[0,1],[1,2]]`, `d [{k:0},{k:1}]` | 3 (`n`, `l`, `d`; items are not slots) | `010102000001010001006b000202000102010001006b01` | `n: the rounds would hold 9 slots, above the limit of 6 slots` | `010102000001010001006b000202000102010001006b010302000203010001006b02` | `field:"n", left:11` |
| 10 | `bytes` / `sized` names | `u8(0,n), bytes(1,b,2), sized(2,s,0)` | `n [1,1]`, `b [00 00, 01 01]`, `s [09, 09]` | 3 (`n`, `b`, `s`) | `010100000901010109` | `n: the rounds would hold 9 slots, above the limit of 6 slots` | `01010000090101010901020209` | `field:"n", left:4` |

For rows 1 to 10 the packet written at `maxSlots` unpacks (`{ok:true}`) with the same scheme, and the row
unpack gives packs again to the same hex (test AC-2). Unpack and pack refuse at the same round.

### `times` and one counter per call

| # | Scheme | Row | Limit | Outcome |
|---|---|---|---|---|
| 11 | `u8(0,n), times(1,0,[u8(1,m), when(2,eq(1,1),[u8(2,k)]), when(3,eq(1,2),[u8(3,k)])])` (W = 2) | `n 2, m [1,2], k [7,8]` | `maxSlots 4` | packs `010201070208` |
| 12 | same | `n 3, m [1,2,1], k [7,8,9]` | `maxSlots 4` | `RangeError`: `m: the rounds would hold 6 slots, above the limit of 4 slots` |
| 13 | `u8(0,n), times(1,0,[u8(1,a)]), repeat(2,[u8(2,b)])` (one slot per round) | `n 1, a [1], b [2,3]` | `maxSlots 3` | packs `0101010203` (3 slots) |
| 14 | same | `n 1, a [1], b [2,3,4]` | `maxSlots 3` | `RangeError`: `b: the rounds would hold 4 slots, above the limit of 3 slots` |

### Differences the other packages must close (from the loop 20 table)

Python: never counts an empty group's name (row 1), counts duplicate leaves twice (row 2), and its unpack
charges 8 more slots per name for the first round of each run (U1, AZ-2381). Rust: counts group, `flags` and
flag-byte names (rows 3, 4, 6, 7). C++ has no `repeat`/`times` slots. All rows must give TypeScript's hex and
numbers.

**Naming note (not a slot difference).** Pack names the first value name of the round (row 4: `a`). TypeScript
unpack names the first name `firstName` finds, and a split `flagByte` name comes first (row 4: `m`). The
`field` of an unpack error is therefore not always the member pack names; the numbers (`left`) and the round
are the same.

## 2. AZ-2390 (F33): an empty `times` or `repeat` body is refused when the scheme is built

**Rule.** A round body must hold at least one **member**. Looking through `when` and groups (at any depth), a
member is any field that is not a container, so a body made only of empty `when`s or empty groups is empty. A
member is therefore any value field (a zero-width `bytes` included), a `list`, a `dict`, a `u2`, a flag byte
or flag bit, a `flags` (a member-less `flags` writes its flag byte), a non-empty container's content.
Rationale: every member either names a slot (so `maxSlots` bounds the rounds) or writes a byte (so `maxBytes`
does); only a body with no member charges 0 slots and writes 0 bytes, which is the F33 hole. A zero-width
`bytes` body therefore still builds (the hostile unpack vectors `zero_progress_repeat_*`, `row1`, `row6`,
`row7` rely on it and pass unchanged: unpack refuses it as a round that reads nothing; pack is bounded by
slots, row 21).

**When**: at construction, in `new Scheme` (and so `scheme`, `withLimits`), after `validateRoundNesting` and
before references are bound. **Where**: wherever the round stands: top level, `flags`, a flag bit, `when`,
group, list or dict element. Cost: one walk at build; no per-round cost.

**Text** (`RangeError`, names the member: the kind and the anchor id, as `validateRoundNesting` does):

- `repeat {anchor}: the body holds no member; a round of it would charge no slot and write nothing`
- `times {anchor}: the body holds no member; a round of it would charge no slot and write nothing`

| # | Scheme (TypeScript) | Outcome |
|---|---|---|
| 15 | `repeat(0, [])` | `RangeError`: `repeat 0: the body holds no member; a round of it would charge no slot and write nothing` |
| 16 | `u8(0,n), times(1,0,[])` | `RangeError`: `times 1: the body holds no member; a round of it would charge no slot and write nothing` |
| 17 | `repeat(0, [when(0, eq(0,1), [])])` | `repeat 0: the body holds no member; ...` (a `when` with no member is no member) |
| 18 | `repeat(0, [when(0, eq(0,1), [when(0, eq(0,2), [])])])` | same text (nested empty `when`s) |
| 19 | `repeat(0, [group(g, [])])` | the existing error first: `empty group g: allowed only directly inside flags or a flag bit; move it into flags` (an empty group cannot stand alone) |
| 20 | F33 request shape: `list(items, group(item, [u32(0,n), times(1,0,[])]))` | `RangeError`: `times 1: the body holds no member; ...` at build, under 1 s (measured a few ms); no packet is attempted |
| 21 | `u8(0,n), times(1,0,[bytes(1,v,0)])`, `maxSlots 5`, `{n: 10, v: ten empty buffers}` | builds; pack `RangeError`: `v: the rounds would hold 6 slots, above the limit of 5 slots` |
| 22 | `repeat(0, [flagByte("m")])`, `{}` | builds; packs `01` (a flag byte is a member; no list, no round) |
| 23 | `repeat(0, [flags(0, [])])`, `{}` | builds; packs `01` |
| 24 | `repeat(0,[u8(0,k)])`, `{k:[7,8]}` and `u8(0,n), times(1,0,[u8(1,k)])`, `{n:2,k:[7,8]}` | build; pack `010708`, `01020708` (unchanged) |
| 25 | the same empty body under `flags`, a flag bit `fb.bit(repeat(0,[]))`, a `when`, a group, a list item | refused with the same text (`repeat 1: ...` for the `when` row, whose repeat anchor is 1) |
| 26 | `repeat(0, [flags(0, [group(g, [])])])`, `{g: [true, undefined]}` (not refused: the flags writes a byte) | builds; packs `010100` |

Unpack: not affected (no packet can hold the shape; existing zero-progress guards stay).

## 3. AZ-2383 (U3): a short list in an optional flags position of a `repeat` is refused

**Scheme and row.** `repeat(0, [u8(0,w), flags(1, [u8(1,v)])])` with `{w: [1,2], v: [5]}` packed
`010101050200` (round 2 has no `v`, bit clear) and now fails.

**Rule.** In a `repeat`, a **non-empty** list under a member that a flag bit can leave absent, shorter than the
number of rounds (the longest list; a lone value counts 1), is refused before any round. "Optional" = reached
through `flags` or a flag bit, also through a `when` or a group below them: values, `bool`, a group member, an
empty group's name, each `u2` slot, a `list`, a `dict`. Checked once per `repeat` pack, right after the rounds
cap, before the lone dict/buffer checks. Not affected: an empty list or no list (absent in every round), a
lone value (goes to every round), a full list with `undefined` / `null` entries, a required member (still
`missing x`), a member under a `when` outside `flags` (README `repeat(k, when(k == 1, v))` still packs
`01010902`), and **`times`** (a short list under `flags` still reads as absent for the rounds it does not
reach: `u8 c; times(c) { flags { u8 v } }` with `{c:2, v:[5]}` packs `0102010500`; AZ-2248, README Times).

**Text** (`RangeError`, the member is the short list's name, the first one in round order):
`{member}: {n} items, repeat count {rounds}; give one entry per round, undefined where the member is absent`

| # | Scheme | Row | Outcome |
|---|---|---|---|
| 27 | `repeat { u8 w; flags { u8 v } }` | `{w:[1,2], v:[5]}` | `RangeError`: `v: 1 items, repeat count 2; give one entry per round, undefined where the member is absent` (packed `010101050200`) |
| 28 | same | `{w:[1,2,3], v:[5, undefined]}` | `v: 2 items, repeat count 3; ...` |
| 29 | same | `{w:[1,2], v:[5, undefined]}` and `{w:[1,2], v:[5, null]}` | packs `010101050200` (the old bytes) |
| 30 | same | `{w:[1,2], v:[5,6]}` / `{w:[1,2]}` / `{w:[1,2], v:[]}` / `{w:[1,2], v:5}` | `01010105020106` / `0101000200` / `0101000200` / `01010105020105` (unchanged) |
| 31 | same | `{w:[1], v:[5,6]}` | `missing w` (required member, unchanged) |
| 32 | `repeat { u8 w; flags { bool on } }` | `{w:[1,2], on:[true]}` / `{w:[1,2], on:[true, undefined]}` | `on: 1 items, repeat count 2; ...` / packs `0101010200` |
| 33 | `repeat { u8 w; flagByte m; bit { u8 v } }` | `{w:[1,2], v:[5]}` / `v:[5, undefined]` | `v: 1 items, ...` / packs `010101050200` |
| 34 | `repeat { u8 w; flags { group g { u8 v } } }` | `{w:[1,2], v:[5]}` | `v: 1 items, repeat count 2; ...` |
| 35 | `repeat { u8 w; flags { u2 p, q } }` | `{w:[1,2], p:[1], q:[2,3]}` | `p: 1 items, repeat count 2; ...` |
| 36 | `repeat { u8 w; flags { when w == 1 { u8 v } } }` | `{w:[1,1], v:[5]}` | `v: 1 items, repeat count 2; ...` |
| 37 | `repeat { flags { u8 a; u8 b } }` | `{a:[1], b:[5,6]}` / `{a:[1,2,3], b:[5,6]}` | `a: 1 items, repeat count 2; ...` / `b: 2 items, repeat count 3; ...` |
| 38 | `repeat { u8 k; when k == 1 { u8 v } }` | `{k:[1,2], v:[9]}` | packs `01010902` (not an optional flags position: unchanged) |
| 39 | `u8 c; times(c) { flags { u8 v } }` | `{c:2, v:[5]}` | packs `0102010500` (`times` unchanged) |

One accepted-row change inside TypeScript's own tests: `round-values.test.ts` "the longest list among every
name in the round sets the repeat count" gave `{a:[1], b:[5,6]}` (row 37 shape); it now gives
`{a:[1, undefined], b:[5,6]}`, same bytes `010301050206`.

## 4. AZ-2391 (F34): `sliceRound` and list-item scope

`sliceRound` copied the whole enclosing scope (`{ ...values }`) for every round; `packItem` did the same for
every scalar list or dict item. Both now take a view that reads through to the enclosing scope
(`Object.create(values)` with only the round's lists, or the item, defined on it): per-round cost follows the
names the round holds, not the fields around it. The wire bytes are unchanged (765 earlier tests pass).

| Scheme | Packet | Before | After |
|---|---|---|---|
| 100 top-level `u8`, then `times(65535) { u8 }` | 65 640 B | 1 436 ms | 22 ms |
| 1 000 top-level `u8`, then `times(65535) { u8 }` | 66 540 B | 23 878 ms | 21 ms |
| 100 top-level `u8`, then `list` of 65 535 `u8` | 65 638 B | 1 358 ms | 22 ms |
| 1 000 top-level `u8`, then `list` of 65 535 `u8` | 66 538 B | 24 621 ms | 19 ms |

The tests compare the two sizes in one run (best of 3, `1000 <= 2 x 100 + 5 ms`) for both shapes. Other
packages: record in the batch report whether a round or item copies its enclosing scope.

## 5. TypeScript probes (AZ-2384, AZ-2386, AZ-2387)

### U4 (AZ-2384): split-bit `times`, count above 0 after the byte, body absent: TypeScript packs a clear bit (no change)

Scheme: `fb = flagByte("fb")`, then `fb, u8(0,n), fb.bit(times(1,0,[u8(1,pt)])), fb.bit(u16(2,heading))`
(flag byte, then `n`, then bit 0 = `times(n) { u8 pt }`, bit 1 = `u16 heading`).

| # | Row | Outcome |
|---|---|---|
| 40 | `{n:2, heading:90}` | packs `0102025a00` (flag 02: times bit clear, heading bit set; n = 2; heading) |
| 41 | `{n:2, pt:[], heading:90}` | packs `0102025a00` |
| 42 | `{n:0, heading:90}` | packs `0102005a00` |
| 43 | `{n:2, pt:[5,6], heading:90}` | `RangeError`: `pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte` |

### U6 (AZ-2386): count above 0 behind a clear `when`, no rounds: TypeScript packed it, now refused

Scheme: `u8(0,mode), when(1, eq(0,1), [u8(1,c)]), fb, fb.bit(times(2,1,[u8(2,pt)])), fb.bit(u16(3,heading))`
(`c` is written only when `mode == 1`; the split bit is `times(c) { u8 pt }`). Before this change rows 44
and 45 packed `0100025a00`; row 50 (combined `flags` with the same `when`) did too.

New text (`RangeError`, member = the first name of the round, as the other messages for this shape):
`{member}: the count {ref} is {n} in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold`
(`{n}` is the count as a number; a bigint prints its value). It is raised where the bit is found clear: split
bit (at the bit) and combined `flags` (in order), for a `times` found through `flags`, flag bits, groups and
`when`s whose condition holds. The count is looked at in the row (`values`), only when no field wrote it.

| # | Row | Outcome |
|---|---|---|
| 44 | `{mode:0, c:1, heading:90}` | `RangeError`: `pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold` |
| 45 | `{mode:0, c:1, pt:[], heading:90}` | same text (empty body) |
| 46 | `{mode:0, c:3n, heading:90}` | same text with `3` |
| 47 | `{mode:0, c:0, heading:90}` | packs `0100025a00` (count 0, unchanged) |
| 48 | `{mode:0, heading:90}` (count left out) | packs `0100025a00` (unchanged) |
| 49 | `{mode:0, c:2, pt:[5,6], heading:90}` | `pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte` (unchanged, comes first) |
| 50 | combined `flags(2, [times(2,1,[u8(2,pt)]), u16(3,heading)])` after the same `when`, `{mode:0, c:2, heading:90}` | same text with `2` (packed `0100025a00` before) |
| 51 | `{mode:1, c:1, pt:[5], heading:90}` | packs `01010103055a00` (a holding `when`, unchanged) |
| 52 | plain `times(2,1,[u8(2,pt)])` (no flag byte) after the `when`, `{mode:0, c:1, heading:90}` and `c:0` | `RangeError`: `times: count c was not written` (both; refused before and after) |

### U7 (AZ-2387): `bits`, `packed`, `sized` count behind a clear `when`: TypeScript refuses (no change)

Scheme: `u8(0,mode), when(1, eq(0,1), [u8(1,c)])`, then the counted member (id 2, count id 1) plain, or
`fb, fb.bit(member)`, or `flags(2, [member])`.

| # | Member | Row | Position | Outcome |
|---|---|---|---|---|
| 53 | `bits(2,v,1)`, `packed(1,2,v,1)`, `sized(2,v,1)` | `{mode:0, c:3, v:[1,0,1]}` (`sized`: `v` = `010203`) | plain, split bit, combined `flags` | `RangeError`: `v: count c was not written` (nine rows) |
| 54 | `bits`, `packed` | `{mode:1, c:3, v:[1,0,1]}` | plain / split bit | packs `01010305` / `0101030105` |
| 55 | `sized` | `{mode:1, c:3, v: 01 02 03}` | plain / split bit | packs `010103010203` / `01010301010203` |
| 56 | any of the three | `{mode:0, c:3}` (**no value**) | split bit, combined `flags` | **packs `010000`** (a clear bit: nothing is dropped). Not refused; the parent decides whether the no-value row must refuse in every package |

## 6. What the other packages need from this table

- Slot rule: section 1 rows 1 to 14 (hex, messages, numbers).
- AZ-2390: the construction rule and text of section 2; a body of only empty containers is refused; a
  zero-width `bytes`, a flag byte and a member-less `flags` are members.
- AZ-2383: section 3, `repeat` only; `times` keeps accepting a short list under `flags`.
- U4 (rows 40 to 43) matches the decision; U7 (rows 53 to 55) matches; U6 (rows 44 to 52) changed.
