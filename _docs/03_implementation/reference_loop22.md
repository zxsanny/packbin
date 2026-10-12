# Loop 22 reference: no-value count behind a clear when (AZ-2410, U11), default maxSlots 1 048 576 (AZ-2415, U17), probe rows for AZ-2412, AZ-2413, AZ-2414

TypeScript is the reference package (problem D1). Every row below was produced by `typescript/src` on `dev`
(Node v22.23.0, darwin). Pinned by `typescript/tests/loop22-novalue-count.test.ts` (section 1) and
`typescript/tests/loop22-max-slots.test.ts` with `typescript/tests/support/unpack-memory.ts` (section 2).
Builder syntax is TypeScript; hex is the whole packet, type byte `01` included. Each package keeps its own error
type; copy the message text unless the package's error style forbids it, then report the difference.

## 1. AZ-2410 (U11): a bits / packed / sized count behind a clear `when`, no value, is refused

**Scheme.** `u8(0,mode), when(1, eq(0,1), [u8(1,c)])`, then the counted member (id 2, count id 1):
`bits(2,v,1)`, `packed(1,2,v,1)` (width 1) or `sized(2,v,1)`; in three positions: plain (member directly),
split bit (`fb = flagByte("fb"); fb, fb.bit(member)`), combined `flags(2, [member])`.

**Rule.** Looked at where the member's bit is found clear (split bit: at the bit; combined `flags`: in order),
for a `bits`, `packed` or `sized` reached through `flags`, flag bits, groups and `when`s whose condition holds:
if no field wrote the count (`!wrote.has(ref)`) and the row holds the count as a valid whole number whose value
after the `packed` bias (0 or -1; 0 for `bits` and `sized`) is above 0, pack is refused. Count 0, an absent
count, a count that is not a valid count (negative, not an integer) are not refused here (as for `times`). The
refusal is raised after the existing "value given but its condition or count is not written" check, so a row
that gives a value keeps that older text. It does not depend on the member having a value: the same check runs
for a member with a value, but that case is already refused earlier (row 53, `count c was not written`, because
the set bit makes pack write the member). A count written by a holding `when` is in `wrote`, so no refusal.

**Text** (`RangeError`; member = the member name; `{n}` = the count as the row gives it, before any bias; a
bigint prints its value):
`{member}: the count {ref} is {n} in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`

Same wording as the loop 21 `times` text except the tail (`so its times reads no round` becomes `so the member
reads nothing`), because there is no round.

Row 56 is the only row that changes. `v` is the member name; the text is identical for the three kinds.

| # | Member | Row | Position | Before (HEAD) | After |
|---|---|---|---|---|---|
| 56 | `bits`, `packed`, `sized` | `{mode:0, c:3}` (no value) | split bit | packs `010000` | `RangeError`: `v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold` |
| 56 | the three | `{mode:0, c:3}` (no value) | combined `flags` | packs `010000` | same text |
| 56 | the three | `{mode:0, c:4n}` | split bit | packs `010000` | same text with `4` |
| 56 | the three | `{mode:0, c:3}` | plain | `RangeError`: `v: count c was not written` | unchanged (plain never reached the clear-bit path) |
| 56a | the three | `{mode:0, c:0}` | split bit, combined `flags` | packs `010000` | packs `010000` (count 0, unchanged) |
| 56b | the three | `{mode:0}` (count left out) | split bit, combined `flags` | packs `010000` | packs `010000` (unchanged) |
| 56c | the three | `{mode:1, c:3}` (holding when, no value) | split bit, combined `flags` | packs `01010300` | packs `01010300` (unchanged) |
| 56d | `packed(1,2,v,1,-1)` (bias -1) | `{mode:0, c:1}` / `{mode:0, c:3}` | split bit | packs `010000` / packs `010000` | packs `010000` (count 1 minus 1 is 0) / refused with `3` |

Rows 53 to 55 are unchanged (checked in `loop22-novalue-count.test.ts` and `loop21-parity-probes.test.ts`):

| # | Row | Position | Outcome |
|---|---|---|---|
| 53 | `{mode:0, c:3, v:[1,0,1]}` (`sized`: `v` = `010203`) | plain, split bit, combined `flags` | `RangeError`: `v: count c was not written` (nine rows) |
| 54 | `{mode:1, c:3, v:[1,0,1]}` (`bits`, `packed`) | plain / split bit | packs `01010305` / `0101030105` |
| 55 | `{mode:1, c:3, v: 01 02 03}` (`sized`) | plain / split bit | packs `010103010203` / `01010301010203` |

Before/after of the whole 45-row probe grid (3 kinds x 3 positions x 5 rows: no value `c:3`, `c:0`, count left
out, value with `c:3`, holding when with no value): the only cells that changed are the six no-value `c:3` cells
of the split bit and combined `flags` positions (three kinds x two positions), `010000` to the refusal above.

**One existing test changed with the rule.** `loop21-parity-probes.test.ts` "observed: with no value given, a
split bit or combined flags packs a clear bit" pinned row 56 as `010000`; it now pins the refusal for `c:3` and
the clear bit for `c:0` (the spec names row 56 as the one row that changes).

## 2. AZ-2415 (U17): default maxSlots 1 048 576

**Change.** `Scheme.DefaultMaxSlots` 4 194 304 to 1 048 576 (`typescript/src/index.ts`). `maxRounds` (65 535) and
`maxBytes` (16 MiB) unchanged. Raising per scheme (`new Scheme(..., { maxSlots })`, `withLimits`) works as before.
Messages carry the number from the scheme (`{slots} slots, above the limit of {maxSlots} slots`), so only the
numbers moved.

### Slot totals that moved (how they are derived)

A round of width W refuses at the first round r with `r x W > maxSlots`; that round would hold `r x W` slots.

| Case | W | Old first refused round | Old text | New first refused round | New text |
|---|---|---|---|---|---|
| `pack_slots_over_limit` (`u32 n; times(n) { 65 u8 }`, n 65 535) | 65 | 64 528 (4 194 320) | `m0: the rounds would hold 4194320 slots, above the limit of 4194304 slots` | 16 132 (16 132 x 65) | `m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots` |
| `pack_element_times_over_budget` (list of 40 items, each `u32 n = 65 535; times(n) { u64 k }`) | 1 | none: 2 621 400 slots passed the old limit only after the bytes budget refused at 16 777 223 bytes | `k: the packet would be 16777223 bytes, above the limit of 16777216 bytes` | 1 048 577 (item 17, round 17) | `k: the rounds would hold 1048577 slots, above the limit of 1048576 slots` |
| unpack of the 4 259 780-byte `pack_slots_over_limit` packet at the default | 65 | `left` 65 520 | | `left` 3 211 260 | |
| unpack, 36-name `when` body (W = 37 with `k`), 1 MiB packet of one-byte rounds | 37 | refused at round 65 536 by `maxRounds` (`left` 983 041) | | round 28 340 by slots (`left` 1 020 237) | |

`pack_element_times_over_budget` is the one hostile pack case whose rule changes: with the new default the
five growable packages refuse it by slots, not by the bytes budget it was written to reach (see Discovered in the
batch report). TypeScript keeps the bytes-budget element route in `pack-output-budget.test.ts` with 16 items of
65 535 rounds, each round one lone 16-char `utf8` (18 bytes a round, 1 048 560 slots, under the limit): packs
refused with `s: the packet would be 16777233 bytes, above the limit of 16777216 bytes`; with `maxBytes`
33 554 432 it packs 18 874 147 bytes and unpacks.

### Memory A/B method (reproducible by Java, C#, Python, Rust)

**Shape F10** (the one in the loop 21 security report, 4.3 MB, 4 194 240 slots, just under the old limit): a
scheme `list items` of `group item` { id0 `u8 n`; id1 `times` anchor 1, count = id0 { 64 `u8` members, ids 1 to
64, distinct names k0 to k63 } }. The packet is built as bytes, not by a pack call (pack would charge the same
limit): type byte `01`, list count `ffff` (65 535 items, little endian u16), then 65 535 items of `01` (n = 1)
followed by 64 bytes of `01` (the one round of 64 values). Length 3 + 65 x 65 535 = **4 259 778 bytes**. Each
item charges one round of 64 slots, so the whole packet needs 4 194 240 slots (at the old limit it unpacks;
at 1 048 576 it is refused at the 16 385th item, after 16 384 items = 1 048 576 slots).

A second shape **wide** (hostile `pack_slots_over_limit` as a packet): `u32 n; times(n) { 65 u8 }`, n = 65 535,
all bytes `01`: 4 259 780 bytes, 4 259 775 slots (above both limits; refused at round 64 528 before, 16 132
after).

**Procedure** (one fresh process per run; peak resident set, not heap):

1. Build the scheme with the default limits (or with `maxSlots` set), build the packet above, and note the
   process peak RSS as `idle` (the packet is already allocated).
2. Unpack once with a handler that only counts rows.
3. Report the outcome, the unpack time, and peak RSS (`peak`) and `peak - idle` (`unpackPeak`).

TypeScript: the script is `typescript/tests/support/unpack-memory.ts` (arguments: shape `f10` or `wide`, then an
optional raised `maxSlots`); peak RSS is `process.resourceUsage().maxRSS` (kilobytes on every platform).

```
# after (working tree)
node typescript/tests/support/unpack-memory.ts f10
node typescript/tests/support/unpack-memory.ts f10 4194304      # AC-3, raised
node typescript/tests/support/unpack-memory.ts wide
# before (HEAD): the same script run against an archive of HEAD
T=$(mktemp -d); git archive HEAD typescript | tar -x -C "$T"
ln -s "$PWD/typescript/node_modules" "$T/typescript/node_modules"
mkdir -p "$T/typescript/tests/support"; cp typescript/tests/support/unpack-memory.ts "$T/typescript/tests/support/"
node "$T/typescript/tests/support/unpack-memory.ts" f10
```

Other languages: use the platform's peak RSS for a fresh process (`/usr/bin/time -l` on macOS reports `maximum
resident set size` in bytes; `/usr/bin/time -v` on Linux in kilobytes; Python `resource.getrusage(RUSAGE_SELF)`
(bytes on macOS, KB on Linux); Java `-Xmx` large enough and the OS figure; Rust `getrusage`). Take `idle` after
the packet and scheme exist, before the unpack call; run each case three times and report the middle one.

### TypeScript numbers (darwin, Node v22.23.0; three runs, spread under 2 percent)

| Shape | Limit | Outcome | Unpack time | Peak RSS | Above idle (about 86 MB) |
|---|---|---|---|---|---|
| F10 | before: 4 194 304 | unpacks (`ok: true`, 1 row kept) | 1 400 to 2 600 ms | **1 070 MB** | 983 MB |
| F10 | after: 1 048 576 | refused at item 16 385 (`field: "k0"`, `left` 3 194 814), no row | 320 to 470 ms | **353 MB** | 267 MB |
| F10 | raised to 4 194 304 (AC-3) | unpacks (`ok: true`) | about 1 400 ms | 1 070 MB | 983 MB |
| wide | before | refused at round 64 528 (`left` 65 520) | 340 ms | 235 MB | 149 MB |
| wide | after | refused at round 16 132 (`left` 3 211 260) | 100 ms | 153 MB | 67 MB |

**New ceiling, TypeScript: about 355 MB peak resident (267 MB above an idle process) for the F10 shape**, down
from 1 070 MB (983 MB above idle): 33 percent of the old peak, 27 percent of the old increase. That is a little
above the quarter the spec asks for ("at most a quarter of the pre-change worst case"): the slot count is
exactly a quarter, but a fixed floor (runtime, the 4.3 MB packet, garbage the collector has not returned) does
not shrink. It is under the 400 MB line of problem D4, so no lower value is proposed from TypeScript; the
parent decides whether "a quarter" is read as slots or as peak RSS.

The F10 shape stays the worst case for TypeScript: it keeps one row object per item. Any package whose new
worst case passes 400 MB must report it before the parent picks a lower value.

## 3. Probe rows for the other packages (read-only; no TypeScript change)

All rows pack with `scheme(1, ...)`; `g` members are plain `x.name` accessors. Hex is the whole packet.

### 3a. AZ-2414: a short `times` list under `flags` (the bytes Rust must match)

Two shapes carry the words "times" and "flags" in the README / specs; both are recorded.

**Shape A: `flags` inside the times body** (README Times, AZ-2248; the shape the spec cites). `u8(0,c), times(1,0,[flags(1,[u8(1,v)])])`:

| # | Row | Outcome |
|---|---|---|
| A1 | `{c:2, v:[5]}` (short) | packs `0102010500` (round 1 has `v`, round 2's bit is clear) |
| A2 | `{c:2, v:[]}` (empty) | packs `01020000` |
| A3 | `{c:2}` (absent) | packs `01020000` |
| A4 | `{c:2, v:[5,6]}` (full) | packs `010201050106` |
| A5 | `{c:2, v:[5,undefined]}` / `{c:2, v:[5,null]}` | packs `0102010500` |
| A6 | `{c:2, v:5}` (lone) | packs `010201050105` (goes to every round) |
| A7 | `{c:0}` | packs `0100` |

With a required member beside it, `u8(0,c), times(1,0,[u8(1,w), flags(2,[u8(2,v)])])`:

| # | Row | Outcome |
|---|---|---|
| A8 | `{c:2, w:[1,2], v:[5]}` | packs `01020101050200` |
| A9 | `{c:2, w:[1,2], v:[]}` | packs `010201000200` |
| A10 | `{c:2, w:[1,2], v:[5,6]}` | packs `0102010105020106` |
| A11 | `{c:3, w:[1,2,3], v:[5]}` | packs `010301010502000300` |

The same short list under a **`repeat`** is refused (AZ-2383, AC-2 of AZ-2414): `repeat(0,[u8(0,w), flags(1,[u8(1,v)])])`
with `{w:[1,2], v:[5]}` gives `RangeError`: `v: 1 items, repeat count 2; give one entry per round, undefined where the member is absent`;
`{w:[1,2], v:[5,undefined]}` packs `010101050200`.

**Shape B: `times` as a `flags` member** (the `times` is the flag bit's field; the count is its own field). These
do not accept a short list: they fail naming the list, in TypeScript (`flags-times-repeat-member.test.ts`):

| # | Scheme | Row | Outcome |
|---|---|---|---|
| B1 | `flags(0,[u8(0,n), times(1,0,[u8(1,pt)])])` | `{n:2, pt:[5]}` / `{n:2, pt:[]}` / `{n:2}` | `missing pt` (all three) |
| B2 | same | `{n:2, pt:[5,6]}` / `{n:2, pt:5}` | packs `0103020506` / `0103020505` |
| B3 | same | `{n:1, pt:[5,6]}` | `pt: 2 items, times count 1` |
| B4 | `u8(0,n), flags(1,[times(1,0,[u8(1,pt)])])` | `{n:2, pt:[5]}` / `[]` / absent | `missing pt` |
| B5 | same | `{n:2, pt:[5,6]}` / `{n:0}` | packs `0102010506` / `010000` |
| B6 | split bit `fb.bit(times(1,0,[u8(1,pt)]))` after `u8 n` | `{n:2, pt:[5]}` / `[]` | `missing pt`; `{n:2, pt:[5,6]}` packs `0102010506` |

If AZ-2414 means shape B, TypeScript does not accept a short list there (it refuses), so the spec would be
asking Rust to match a refusal; that needs the parent's word (see the batch report).

### 3b. AZ-2413: the three repeat shapes (TypeScript outcome; Python must match, per the spec only where the five agree)

| # | Shape | Row | Outcome |
|---|---|---|---|
| R1a | `repeat(0,[u8(0,k)])` lone value | `{k:7}` | packs `0107` (one round) |
| R1b | same | `{k:[7]}` / `{k:[7,8]}` | packs `0107` / `010708` |
| R2a | `repeat(0,[u8(0,a), u8(1,b)])` lone value beside a list | `{a:[1,2], b:7}` | packs `0101070207` (the lone value goes to every round) |
| R2b | same | `{a:1, b:[5,6]}` | packs `0101050106` |
| R2c | same, both full | `{a:[1,2], b:[5,6]}` | packs `0101050206` |
| R2d | **short required list** | `{a:[1,2,3], b:[5]}` | `RangeError`: `missing b` (required member: refused, no bytes) |
| R2e | short required list | `{a:[1], b:[5,6,7]}` | `RangeError`: `missing a` |
| R2f | empty required list | `{a:[1,2], b:[]}` / `{a:[1,2]}` | `RangeError`: `missing b` |
| R3a | `repeat(0,[u8(0,k), when(1,eq(0,1),[u8(1,v)])])` list outside `flags`, with values | `{k:[1,2], v:[9]}` | packs `01010902` (round 2's `when` is false, so `v` is not read) |
| R3b | same | `{k:[1,2], v:[9,8]}` | packs `01010902` (extra entry ignored) |
| R3c | same | `{k:[1,1], v:[9,8]}` | packs `0101090108` |
| R3d | same, short (a held `when` with too few entries) | `{k:[1,1], v:[9]}` | `RangeError`: `missing v` |
| R3e | same, lone value | `{k:[1,1], v:9}` | packs `0101090109` |
| R3f | same, no value needed | `{k:[2,2], v:[9]}` | packs `010202` |
| R3g | same, value absent but needed | `{k:[1,2]}` / `{k:[1,1]}` | `RangeError`: `missing v` |

Rule from these rows: the round count is the longest list; a lone value goes to every round; a short list is
refused with `missing {name}` where a round needs the member and the list has run out (a required member, or a
held `when`); a member that no round reaches (a clear `when`) may have any list length.

So of the three shapes the spec names: the **lone value** (R1, R2a) and the **`when` list outside `flags`** (R3a
to R3c, R3e) pack in TypeScript; the **short required list** (R2d, R2e) is **refused** in TypeScript with
`missing {name}`, so "Python refuses, the other five pack" does not hold for that shape in TypeScript (Python
refusing it is already the TypeScript rule; see the batch report).

### 3c. AZ-2412: per-name repeat lists without `__repeat__` groups

TypeScript has no `__repeat__`-style round groups: a `repeat` takes rounds only as per-name lists in the row
(the form Rust refuses without groups). `repeat(0,[u8(0,n), u8(1,x)])`:

| # | Row | Outcome |
|---|---|---|
| C1 | `{n:[1,2], x:[5,6]}` | packs `0101050206` (two rounds) |
| C2 | `{n:[1,2]}` / `{x:[5,6]}` | `RangeError`: `missing x` / `missing n` |
| C3 | `{n:[1,2], x:5}` | packs `0101050205` (lone value to every round) |
| C4 | `{}` | packs `01` (no rounds) |

For the hostile spec (AZ-2417) the TypeScript bytes for the row in the problem text are `0101050206`
(`{n:[1,2], x:[5,6]}`): the five packages that take per-name lists pack those two rounds; Rust refuses (AZ-2412).
