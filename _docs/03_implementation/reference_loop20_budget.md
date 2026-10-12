# Loop 20 reference: pack output budget (AZ-2354) and repeat round cap (AZ-2355)

TypeScript is the reference package (problem D1). Every row below was produced by `typescript/src` on `dev`
(Node v22.23.0, darwin) and is pinned by `typescript/tests/pack-output-budget.test.ts` and
`typescript/tests/pack-repeat-round-cap.test.ts`. C#, Python, Java and Rust align to these rows in wave 1b:
same outcome, same member named, same numbers in the message. Each package keeps its own error type
(TypeScript `RangeError`, Python `ValueError`, Java `IllegalArgumentException`, C# `ArgumentException`,
Rust `PackError`). Copy the message text exactly unless the package's error style forbids it; then report
the difference.

## The rules

### Limits

| Limit | Default | Applies to | Refused value |
|---|---|---|---|
| `maxRounds` | 65 535 | rounds of one `repeat` or `times` (pack and unpack) | below 1, not an integer, above 2^53 - 1 |
| `maxSlots` | 4 194 304 | slots charged by all rounds of one pack or unpack call | same |
| `maxBytes` | 16 777 216 | length of one packed packet, type byte included (pack only) | same |

- TypeScript: `new Scheme(type, fields, { maxRounds?, maxSlots?, maxBytes? })` and
  `scheme.withLimits({ maxRounds?, maxSlots?, maxBytes? })`. A member left out of `withLimits` takes the
  **default**, not the source scheme's value (unchanged from loop 19). `Scheme.DefaultMaxBytes = 16_777_216`.
- Invalid limit text, the same for all three names:
  - `maxBytes: expected a positive integer up to 9007199254740991`
  - `maxRounds: expected a positive integer up to 9007199254740991`
  - `maxSlots: expected a positive integer up to 9007199254740991`
  - Refused values checked: `0`, `-1`, `1.5`, `NaN`, `2^53` (9007199254740992). Raised by the constructor and
    by `withLimits`.

### Bytes (`maxBytes`)

- Checked at every append, before it is written. With `L` the packet length so far (type byte included) and
  `n` the size of the append, the append is refused when `L + n > maxBytes`. A packet of exactly `maxBytes`
  bytes packs.
- Message: `{member}: the packet would be {L + n} bytes, above the limit of {maxBytes} bytes`.
- One append per member write; the member named is the one being written:

| Write | Append size | Member named |
|---|---|---|
| int / float | its width | the field |
| `bytes` | its size | the field |
| `utf8` | 2 + UTF-8 length, **one** append (length prefix and text together) | the field |
| `sized`, `bits`, `packed` | their bytes | the field |
| `u2` | its packed bytes | its first slot |
| `list` / `dict` count prefix | 2 | the list / dict |
| `dict` key | 2 + UTF-8 length | the dict |
| split flag byte | 1 | the `flagByte` name |
| combined `flags` byte | 1 | the first name its members declare, depth-first (through `when`, `repeat`, `times`, nested `flags`, nameless groups) |

- `when`, `repeat`, `times`, groups and flag bits write no bytes of their own. Setting a bit in a combined
  flag byte already written is not an append.
- The type byte is always written (`maxBytes >= 1`); a bare scheme packs `01` at `maxBytes: 1`.
- No bytes are returned on refusal (the call throws). TypeScript keeps memory near the budget: the output
  buffer doubles but never past `maxBytes`.

### Slots (`maxSlots`)

- **Width of a round** = the number of names unpack gives an entry per round: each field's own name, each
  `u2` slot, a `bool`, a `list` / `dict` / `bytes` / `sized` name (1 each), plus the names under `when`,
  `flags`, flag bits and groups. A **non-empty group's own name is not counted** (only its members); an
  empty group's name is counted. Flag bytes are not counted. This is exactly the width unpack charges
  (`roundNames(fields, false).size` in `typescript/src/rounds.ts`, `refuseRound` in `walker.ts`).
- **When**: as each round **starts, before any byte of that round** is written. `slots + width > maxSlots`
  refuses the round; otherwise `slots += width` and the round is written.
- **Scope**: one counter per pack call, shared by every `repeat` and `times` at any depth: top level, `flags`
  members, groups, `when`, split bits, list and dict elements (an element's rounds add to the same counter).
- Message: `{member}: the rounds would hold {slots + width} slots, above the limit of {maxSlots} slots`.
- Member named: the first name the round holds in declaration order, depth-first, where a group's own name
  comes before its members (pack's `roundNames(fields, true)`); `{repeat|times} {anchor}` if it holds none.
- Pack refuses at the same round index where the same scheme's unpack refuses the packet.

### Rounds (`maxRounds`)

- `times`: after its count is read from what was written, **before any round**: `count > maxRounds` →
  `{member}: the times count is {count}, above the limit of {maxRounds} rounds` (loop 19 text, unchanged;
  member as for slots).
- `repeat` (AZ-2355): **before any round**, the first name in the round (same order as above) whose value is
  a list with more than `maxRounds` entries is refused:
  `{that member}: the repeat count is {its list length}, above the limit of {maxRounds} rounds`.
  The member named is the one whose list passes the limit, not the round's first member.
- Applies at the top level, in `flags`, a split bit, a `when`, a group and a list / dict element.

### Order when several limits would fire

Pack walks the scheme in order, so the first check reached fires. For one `repeat` / `times`:

1. a count field is its own earlier member: its bytes are checked when it is written (before the `times`);
2. rounds cap (`times` count / `repeat` list length), before any round;
3. (unchanged loop 19 checks: `times` list longer than the count, lone dict, lone byte buffer);
4. per round: **slots first**, then the bytes of that round, append by append.

So when one round would pass both `maxSlots` and `maxBytes`, the slot error is raised.

## AZ-2354 rows

Builder syntax is TypeScript (`typescript/src/index.ts`). Hex is the whole packet.

| # | AC | Scheme (TypeScript) | Scheme (neutral) | Row | Limits | Outcome | Fired |
|---|---|---|---|---|---|---|---|
| 1 | AC-1 | `scheme(1, u32(0, x => x.n), times(1, 0, [utf8(1, x => x.s)]))` | `u32 n; times(n) { utf8 s }` | `{n: 65535, s: "a" × 65535}` | defaults | `RangeError`: `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes` | bytes, at round index 255: 5 + 255 × 65 537 = 16 711 940 written, the next `utf8` append is 65 537 |
| 2 | AC-2 | `scheme(1, list(x => x.items, group(x => x.item, [u32(0, x => x.n), times(1, 0, [u64(1, x => x.k)])])))` | `list items of group { u32 n; times(n) { u64 k } }` | 40 × `{n: 65535, k: 5}` | defaults | `RangeError`: `k: the packet would be 16777223 bytes, above the limit of 16777216 bytes` | bytes, item index 32, round index 15 (3 + 32 × 524 284 + 4 + 15 × 8 = 16 777 215 written; 2 097 136 slots charged) |
| 3 | AC-2 | same | same | same | `maxBytes: 33554432` | packs: 20 971 363 bytes; first 16 `012800ffff0000050000000000000005`; last 16 `05000000000000000500000000000000`; unpacks `{ok: true}` to 40 items, each `n = 65535`, `k` = 65 535 × `5n` | none (2 621 400 slots) |
| 4 | AC-3 | `new Scheme(1, [utf8(0, x => x.s)], { maxBytes: 64 })` | `utf8 s` | `{s: "a" × 61}` | `maxBytes: 64` | packs: 64 bytes, `013d00` + `61` × 61 | none (exactly at the limit) |
| 5 | AC-3 | same | same | `{s: "a" × 62}` | `maxBytes: 64` | `RangeError`: `s: the packet would be 65 bytes, above the limit of 64 bytes` | bytes |
| 6 | AC-3 | `new Scheme(1, [repeat(0, [u8(0, x => x.k)])], { maxBytes: 64 })` | `repeat { u8 k }` | `{k: 7 × 63}` | `maxBytes: 64` | packs: 64 bytes, `01` + `07` × 63 | none |
| 7 | AC-3 | same | same | `{k: 7 × 64}` | `maxBytes: 64` | `RangeError`: `k: the packet would be 65 bytes, above the limit of 64 bytes` | bytes, at the 64th round |
| 8 | AC-3 | `new Scheme(1, [], { maxBytes: 1 })` | (no fields) | `{}` | `maxBytes: 1` | packs: `01` | none (type byte counts) |
| 9 | AC-3 | `new Scheme(1, [u8(0, x => x.a)], { maxBytes: 1 })` | `u8 a` | `{a: 1}` | `maxBytes: 1` | `RangeError`: `a: the packet would be 2 bytes, above the limit of 1 bytes` | bytes |
| 10 | AC-3 | `fb = flagByte("m"); new Scheme(1, [fb, fb.bit(u8(0, x => x.c))], { maxBytes: 1 })` | split byte `m`; bit { `u8 c` } | `{c: 1}` | `maxBytes: 1` | `RangeError`: `m: the packet would be 2 bytes, above the limit of 1 bytes` | bytes, at the flag byte |
| 11 | AC-3 | `new Scheme(1, [flags(0, [u8(0, x => x.c)])], { maxBytes: 1 })` | `flags { u8 c }` | `{c: 1}` | `maxBytes: 1` | `RangeError`: `c: the packet would be 2 bytes, above the limit of 1 bytes` | bytes, at the combined flag byte |
| 12 | AC-3 | `new Scheme(1, [u8(0, x => x.n), flags(1, [times(1, 0, [u8(1, x => x.k)])])], { maxBytes: 2 })` | `u8 n; flags { times(n) { u8 k } }` | `{n: 1, k: 3}` | `maxBytes: 2` | `RangeError`: `k: the packet would be 3 bytes, above the limit of 2 bytes` | bytes, at the combined flag byte (named through the `times`) |
| 13 | AC-3 | `new Scheme(1, [list(x => x.xs, u8(0, x => x.v))], { maxBytes: 2 })` | `list xs of u8` | `{xs: []}` | `maxBytes: 2` | `RangeError`: `xs: the packet would be 3 bytes, above the limit of 2 bytes` | bytes, at the count prefix |
| 14 | AC-4 | `scheme(1, u32(0, x => x.n), times(1, 0, [u8(1, x => x.m0), …, u8(65, x => x.m64)]))` | `u32 n; times(n) { u8 m0 … u8 m64 }` (65 members) | `{n: 65535, m0..m64: 1}` | defaults | `RangeError`: `m0: the rounds would hold 4194320 slots, above the limit of 4194304 slots` | slots, at round index 64 527 (64 527 × 65 = 4 194 255 charged; 4 194 260 bytes written) |
| 15 | AC-4 | same | same | same | `maxSlots: 4259775` | packs: 4 259 780 bytes; first 16 `01ffff00000101010101010101010101`; last 16 `01` × 16; unpacks `{ok: true}`, every `m` a list of 65 535 | none |
| 16 | AC-4 | unpack of row 15's packet with the **default** scheme | | | defaults | `{ok: false, field: "m0", needed: 0, left: 65520}` (unpack refuses at the same round) | slots |
| 17 | order | `new Scheme(1, [u32(0, x => x.n), times(1, 0, [u8(1, x => x.k)])], limits)` | `u32 n; times(n) { u8 k }` | `{n: 3, k: 7}` | `maxSlots: 3, maxBytes: 8` | packs: `0103000000070707` (at both limits) | none |
| 18 | order | same | same | `{n: 10, k: 7}` | `maxSlots: 3, maxBytes: 8` | `RangeError`: `k: the rounds would hold 4 slots, above the limit of 3 slots` | slots (the 4th round would also pass the bytes: slots are checked first) |
| 19 | order | same | same | `{n: 10, k: 7}` | `maxSlots: 3, maxBytes: 7` | `RangeError`: `k: the packet would be 8 bytes, above the limit of 7 bytes` | bytes (3rd round, before slots run out) |
| 20 | order | same | same | `{n: 10, k: 7}` | `maxRounds: 5, maxSlots: 3, maxBytes: 8` | `RangeError`: `k: the times count is 10, above the limit of 5 rounds` | rounds (before any round) |
| 21 | order | same | same | `{n: 10, k: 7}` | `maxRounds: 5, maxSlots: 3, maxBytes: 4` | `RangeError`: `n: the packet would be 5 bytes, above the limit of 4 bytes` | bytes (the count field, before the `times`) |
| 22 | scope | `new Scheme(1, [list(x => x.items, group(x => x.item, [u8(0, x => x.n), times(1, 0, [u8(1, x => x.k)])]))], { maxSlots: 5 })` | `list items of group { u8 n; times(n) { u8 k } }` | `{items: [{n: 3, k: 1}, {n: 3, k: 2}]}` | `maxSlots: 5` | `RangeError`: `k: the rounds would hold 6 slots, above the limit of 5 slots` | slots, accumulated across elements |
| 23 | scope | same | same | `{items: [{n: 3, k: 1}, {n: 2, k: 2}]}` | `maxSlots: 5` | packs: `01020003010101020202` | none (5 slots) |
| 24 | width | `new Scheme(1, [repeat(0, [u8(0, x => x.a), group(1, x => x.g, [u8(1, x => x.b)])])], { maxSlots: 5 })` | `repeat { u8 a; group g { u8 b } }` | `{a: [1, 2], b: [3, 4]}` | `maxSlots: 5` | packs: `0101030204` (width 2: `a`, `b`; `g` not counted) | none |
| 25 | width | same | same | `{a: [1, 2, 3], b: [3, 4, 5]}` | `maxSlots: 5` | `RangeError`: `a: the rounds would hold 6 slots, above the limit of 5 slots` | slots |
| 26 | AC-5 | `scheme(1, u8(0, x => x.a))` | `u8 a` | | none | `maxBytes` = 16 777 216; `withLimits({ maxRounds: 9 }).maxBytes` = 16 777 216; `withLimits({ maxBytes: 64 }).withLimits({ maxSlots: 9 }).maxBytes` = 16 777 216 | |
| 27 | AC-5 | `new Scheme(1, [], { maxBytes: v })`, `withLimits({ maxBytes: v })` | | | `v` in `0, -1, 1.5, NaN, 2^53` | `RangeError`: `maxBytes: expected a positive integer up to 9007199254740991` | |
| 28 | AC-5/6 | row 17's scheme `.withLimits({ maxRounds: 3, maxSlots: 3 })` | | `{n: 3, k: 7}` | | packs `0103000000070707`; existing call forms compile unchanged | |

AC-6: the golden, route and ring fixtures and every other accepted row of the TypeScript suite pack to the
same hex as before (758 / 758 pass).

### AC-1 time and memory (TypeScript)

`/usr/bin/time -l node typescript/tests/support/lone-utf8-budget.ts`, three runs:

| | Pack call | Process wall | Peak RSS |
|---|---|---|---|
| after | 8 to 14 ms | 0.08 to 0.09 s | 135 to 145 MB |
| node + `import` of the package alone | | 0.09 s | 88 MB |
| before (HEAD, heap capped at 1 GB) | `RangeError: Invalid array length` (no member named) | 1.55 s | 1 679 MB |

The suite's AC-1 test runs the same script in a child process and asserts < 1 000 ms and < 256 MiB peak RSS.

## AZ-2355 rows

| # | AC | Scheme (TypeScript) | Scheme (neutral) | Row | Limits | Outcome | Fired |
|---|---|---|---|---|---|---|---|
| 1 | AC-1 | `new Scheme(1, [repeat(0, [u8(0, x => x.k)])])` | `repeat { u8 k }` | `{k: 7 × 65536}` | defaults | `RangeError`: `k: the repeat count is 65536, above the limit of 65535 rounds` | rounds (before any round) |
| 2 | AC-2 | same | same | `{k: 7 × 65535}` | defaults | packs: 65 536 bytes; first 16 `01070707070707070707070707070707`; last 16 `07` × 16; unpacks `{ok: true}`, repack gives the same bytes | none |
| 3 | AC-3 | same | same | `{k: 7 × 70000}` | `maxRounds: 70000` | packs: 70 001 bytes; first 16 `01` + `07` × 15; last 16 `07` × 16 | none |
| 4 | | same | same | `{k: [1, 2, 3, 4]}` | `maxRounds: 3` | `RangeError`: `k: the repeat count is 4, above the limit of 3 rounds` | rounds |
| 5 | | same | same | `{k: [1, 2, 3]}` | `maxRounds: 3` | packs `01010203` | none |
| 6 | | `new Scheme(1, [repeat(0, [u8(0, x => x.a), u8(1, x => x.b)])], { maxRounds: 3 })` | `repeat { u8 a; u8 b }` | `{a: 1, b: [1, 2, 3, 4]}` | `maxRounds: 3` | `RangeError`: `b: the repeat count is 4, above the limit of 3 rounds` | rounds; names `b` (the long list), not `a` |
| 7 | | `flags(0, [repeat(0, [u8(0, x => x.k)])])` | `flags { repeat { u8 k } }` | `{k: [1, 2, 3, 4]}` | `maxRounds: 3` | `RangeError`: `k: the repeat count is 4, above the limit of 3 rounds` | rounds |
| 8 | | `fb, fb.bit(repeat(0, [u8(0, x => x.k)]))` | split bit { `repeat { u8 k }` } | `{k: [1, 2, 3, 4]}` | `maxRounds: 3` | same text as row 7 | rounds |
| 9 | | `u8(0, x => x.m), when(1, eq(0, 1), [repeat(1, [u8(1, x => x.k)])])` | `u8 m; when m == 1 { repeat { u8 k } }` | `{m: 1, k: [1, 2, 3, 4]}` | `maxRounds: 3` | same text as row 7 | rounds |
| 10 | | `list(x => x.items, group(x => x.item, [repeat(0, [u8(0, x => x.k)])]))` | `list items of group { repeat { u8 k } }` | `{items: [{k: [1, 2, 3, 4]}]}` | `maxRounds: 3` | same text as row 7 | rounds |

Before (HEAD): rows 1, 4, 6 to 10 packed (row 1: 65 537 bytes that the same scheme's unpack refuses).

## Errata and per-package differences (parent, 2026-10-12, after waves 1b and the review fix pass)

The table above is TypeScript's. The other packages reproduce its numbers, member names and order of checks; these are the accepted differences (rulings in `batch_02_loop20_report.md` and `review20.md`):

- **Error type**: TypeScript `RangeError`, Python `ValueError` (the missing-field error of a `repeat` is a `KeyError`), Java `IllegalArgumentException`, C# `ArgumentException`, Rust `PackError`.
- **Message text**: Python uses the reference text for the `times` cap (`x: the times count is N, above the limit of M rounds`). Java and Rust keep their loop 19 `times` cap text (existing tests pin it): Java `times: count N is above the limit of M rounds`, Rust `times at id N: count N (from 'n') is over the M rounds a scheme allows; members 'k'`. The `repeat` cap, bytes and slots texts follow the reference in all five. C# quotes the member (`'S': ...`).
- **Member naming**: a split `flagByte()` has no name in Java (`flag_byte`), Python (`flag byte`) and C# (the first member its bits declare); a Java field without an accessor key is named by its field id (`0:`); older Python, Java and Rust messages name a field by id.
- **Limits API**: TypeScript `withLimits({ maxBytes })` and a left-out limit takes the default; Python `with_limits(max_rounds, max_slots, max_bytes)` (same reset); Java `withMaxBytes(long)` keeps the other limits and `withLimits(int, long)` resets `maxBytes` to the default; Rust `with_max_bytes(usize)` is separate and `with_limits(rounds, slots)` keeps `max_bytes`; C# an optional trailing `maxBytes` of `WithLimits` (a `long`, only values below 1 are refused; effective cap 0x7FFFFFC7). Python and C# have no upper bound of 2^53 - 1 on a limit.
- **Slot width** (row 24/25): Rust counts group, `flags` and flag-byte names (its own unpack does, width 3 for `repeat { u8 a; group g { u8 b } }`); Python never counts an empty group's name and counts duplicate leaves twice. Python's unpack charges 8 more slots per name for the first round of each run, so a packet written at exactly `maxSlots` (rows 15/16) is refused by Python's own unpack (`left=66040`): loop 21 decision U1.
- **Rows that do not apply**: Rust has no `times`/`repeat` in a list element (AZ-2354 rows 2, 3, 22, 23, AZ-2355 row 10); C++ is out of AZ-2354/AZ-2355 (caller buffer, fixed arrays).
