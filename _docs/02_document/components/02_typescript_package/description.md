# TypeScript package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Vue, React, and Node.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's client. Vue and React import this package. They do not get their own package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `scheme`, `new Scheme` | type number, fields by order id | scheme | No | a type number outside 0..255, a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flag byte is not read earlier in the same scope, a bool or empty group that is not directly in `flags` or a flag-byte bit, an `eq` or count id that is not an earlier field of the same scope, a member name used inside an unanchored group and outside it, or a `repeat` or `times` inside a `repeat` or `times` round (§7) |
| `flags`, `flagByte(...).bit` | fields | field | No | a ninth bit on one flag byte (§7) |
| `BinaryPacker.pack` | scheme, row | bytes | No | `RangeError` for an integer or float that does not fit its width or is not a number (§7) |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never throws on bytes (see §7) |
| `Scheme.withLimits`, `maxRounds`, `maxSlots`, `Scheme.DefaultMaxRounds`, `Scheme.DefaultMaxSlots`, type `SchemeLimits` | `{ maxRounds?, maxSlots? }` | a new scheme with those unpack limits | No | `RangeError` for a limit that is not a positive safe integer (§7) |

**Input DTOs**:

```
Value:
  fields: name to number, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: number — sum of present field widths
ShortPacket:
  field: string
  needed: number
  left: number
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `start` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: deprecate the npm version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Source layout: `walker.ts` is the unpack walker, `pack-fields.ts` the pack walker (split out of `walker.ts` in loop 11), `flag-scope.ts` the construction checks for flag bits (`validateFlagScopes`) and for where a bool or empty group may stand (`validatePresenceMarks`). Added in loop 13: `ref-scope.ts` binds every `eq` and count id to a member name (`bindReferences`, `refName`), `member-names.ts` refuses a name with two places (`validateMemberNames`), and `rounds.ts` holds the round logic (`validateRoundNesting`, `roundNames`, `roundCount`, `sliceRound`, `RoundLists`, `appendList`), used by both walkers. Loop 15: the unpack counters (`maxRounds`, `maxSlots`, `slots`) live on `ViewCursor` in `kinds.ts`, and `refuseRound` in `walker.ts` checks them. A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime data view writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return an error value, never an exception (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- A `when` or count inside a `list` or `dict` element names an earlier field of that element; one with nothing earlier in its scope is a construction error (loop 13). A non-empty group as a `list` or `dict` element does not pack per item (AZ-2102), also outside rounds
- A flags group with fields is on only when its own member or an `int`, `float`, `bytes`, `utf8`, `list` or `dict` child has a value (`scalarChildNames` in `kinds.ts`). Values only in `u2`, `bits`, `sized` or `packed` children leave the bit clear and are dropped (AZ-2128)
- `when(eq(boolId, false))` packs its body, but `false` is absent on the wire, so the package's own unpack never matches it and fails (AZ-2126). `eq` may name any value field here (float, bytes, utf8, bool), where Java, C++ and Rust take integer or bool only; a float source with a decimal `eq` packs and its own unpack fails (AZ-2126)
- Flags under a split-form flag bit that wraps a group, and a `flags` placed directly inside `flags`, are dropped on pack (AZ-2183). A dict key equal to a member name overwrites that member on pack, and a decoded `__proto__` key makes the row inherit members (AZ-2184)
- `times` pack drops list entries beyond the count (`{n:2, v:[1,2,3]}` packs `01020102`); C# throws (AZ-2185). The same member name declared twice in one place builds and loses a value (AZ-2188)
- A lone non-list value for a name in a round is broadcast to every round, pinned by a test; C# packs it into round 0 only (AZ-2182). A group written as a nested object inside a round counts as present in every round, so `{mark:{v:[7,undefined,9]}}` throws `missing v`; a round takes flat per-round lists
- With `u64(n)` driving `sized`, `times` or `packed`, the unpacked row holds `n` as a `bigint` and pack refuses a `bigint` count, so that row cannot repack (AZ-2112)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In TypeScript it is a short-packet result built by `unreadable` in `walker.ts` (and `readUtf8` in `kinds.ts`): the counted field, `needed` 0, the bytes left. A `times` round uses the name of its first body field as the label, a list or dict element uses the list's name. `bits` keeps accepting a `u64` (bigint) count up to `Number.MAX_SAFE_INTEGER`; a bigint above that cannot be exact and fails as a bad count.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. The `Scheme` constructor runs `validateFlagScopes` (`flag-scope.ts`) after `flatten`; a violation is a `RangeError`.

**Bool rule** (loop 12). A `bool` or an empty group is a mark with no bytes, only a flag bit. It is allowed only as a direct member of `flags` or the field of a flag-byte bit; anywhere else (top level, a non-empty group, `when`, `repeat`, `times`, a list or dict element) `validatePresenceMarks` throws a `RangeError` naming the member. Its bit is set only for `true` (`bitOn` in `fields.ts`): `false`, no value, and any other value (`1`, `"yes"`) leave it clear. Unpack sets the member to `true` only under a set bit; a clear bit leaves it out of the row. A ninth bit throws a `RangeError` when it is declared: `flags(...)` with nine fields, or the ninth `.bit(...)` on a flag-byte handle.

**Constructor** (loop 12). `new Scheme(typeNumber, fields)` runs every check: the type number (0..255), `validateFieldIds`, then `flatten`, `validateFlagScopes`, `validatePresenceMarks`, `validateMemberNames` and `validateRoundNesting` (the last two since loop 13) on the flat list, and `bindReferences` last. `scheme(...)` only calls it, so both refuse the same schemes with the same message. `Scheme.fields` holds the flattened fields, with the `when`, `sized`, `bits`, `packed` and `times` fields as copies that carry their bound member name.

**Reference scope** (loop 13, `ref-scope.ts`). Every `eq` field id, and the count id of `sized`, `bits`, `packed` and `times`, names a value field read earlier in the same scope: the top level, a `repeat` or `times` body, a `list` or `dict` element, or an unanchored group (its ids restart at 0). `flags`, flag bits, an anchored group and `when` share the scope around them, and a nested scope is closed in both directions. A count must name an integer (`int` or a `u2` slot); `eq` may name any value field. A later field, an unknown id, an outer field from inside a body, and a field of an earlier nested scope are a `RangeError` naming the referring and the referenced id. `bindReferences` runs last in the constructor and gives the scheme a copy of each reference field with the member name filled in (`Scheme.fields`; `index.d.ts` is unchanged), so pack and unpack no longer search the scheme for an id on every call. `eq` compares numbers and bigints by value (`sameValue` in `kinds.ts`): `1`, `1n` and an unpacked `1n` match, so a `u64` source works.

**Range checks** (loop 13, `writeInt` and `writeFloat` in `kinds.ts`). Pack refuses with a `RangeError` that starts with the member name: a value that is not a `number` or `bigint` for an integer field, a number that is not a safe integer, a number or bigint outside the width and sign (an integer number past 2^53 that fits the width gets "pass a bigint"), a `bigint`, string or other non-number for a float, and a finite value an `f32` would turn into an infinity. NaN and the infinities pass for floats, and `-0` packs as `0`. The check is made before the field is written, so a failed pack returns no bytes and a failed `PackSession.pack` leaves the pad position alone. Unpacked `u64` and `i64` rows pack again, except where a `u64` drives a count (see §7).

**Member names** (loop 13, `member-names.ts`). A row is one flat map: the members of a group are merged into the row beside the group's own name. A name declared inside an unanchored group and anywhere else, including a group named like one of its children or like a member of another unanchored group, would let one value overwrite the other, so the constructor throws a `RangeError` naming the member. An anchored group, `when`, `flags`, `repeat` and `times` share the place around them, so two `when` branches may write one member.

**Flags in groups** (loop 13, `fields.ts`). `flatten` also flattens the members of a `flags`, and `collectFlagBits` descends into groups and into a flag bit's field, so a `flags` inside an anchored or unanchored group is packed (`{a:1, g:{b:2, c:3}}` packs `0101020103`). The value of a flag byte is walk state only: unpacked rows have no `""` key, no `motion` key for a split-form byte, and no list of flag bytes inside a round.

**Round limits** (loop 15, AZ-2217; `index.ts`, `kinds.ts`, `walker.ts`). A `Scheme` carries `maxRounds` (default `Scheme.DefaultMaxRounds`, 65,535) and `maxSlots` (default `Scheme.DefaultMaxSlots`, 4,194,304). `scheme.withLimits({ maxRounds, maxSlots })` returns a new `Scheme` with the same type number and fields; a member left out takes the default, not the receiver's value, so two chained calls drop the first, and the receiver is unchanged. The constructor takes the same object as an optional third argument (`SchemeLimits`, exported), and `scheme(...)` does not. A limit that is not a positive safe integer throws a `RangeError` (`checkedLimit`); there is no unlimited value. `unpackBody` puts both limits and a slot counter on the call's `ViewCursor`, and the `repeat` and `times` branches of `unpackFields` call `refuseRound(cur, started, width)` as each round starts, before the round is read or padded; `width` is the size of `roundNames` of the body. The round that would be the 65,536th of one field, or would take the slot total past `maxSlots`, returns `unreadable(...)` (the first body field's name, `needed` 0, the bytes left): no row, no handler call. A `times` count is not refused up front. Dispatch uses the limits of the matched handler's scheme.

**Rounds** (loop 13, `rounds.ts`). A round is addressed by index. The names a round can hold are its own fields and those under `when`, `flags`, flag bits and groups. Pack reads item i of each name's list for round i (`sliceRound`), so a `when`, flags or group inside a round packs (it threw); a `repeat` runs as many rounds as its longest list and a `times` its borrowed count. Unpack builds one list per name with one entry per round, `undefined` where the round skipped it (`RoundLists`, padded as rounds set values; `JSON.stringify` shows `null`), and a bool under flags is `true` or `undefined`. A `when` or count read inside a round sees only that round's own value, with no fallback to a same-named outer value. `validateRoundNesting` refuses a `repeat` or `times` inside a round, directly or under `when`, `flags`, a flag bit or a group, with a `RangeError` naming the nested container; a `list` or `dict` element starts outside any round. `walker.ts` and `pack-fields.ts` call `rounds.ts`; the branches that handle a nested round there are unreachable while the refusal stands and matter again when AZ-2127 lifts it.

**Breaking changes for callers, loop 11** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers, loop 12**:
- A `bool` or empty-group mark that is `false` (or any value other than `true`) packs a clear bit (`0100`, was `0101`), as in Python. Unpack leaves the member out; it used to read `true`.
- A `bool` or empty group outside a flag bit is refused at construction. It never round-tripped: it always unpacked `true`.
- A ninth flag bit is refused when declared. Pack used to write it, and the package's own unpack then failed with trailing bytes.
- `new Scheme(...)` refuses what `scheme(...)` refuses, and its `fields` is the flattened list. The constructor used to run no check.

**Breaking changes for callers, loop 13**:
- Pack throws a `RangeError` for an integer outside its width, a non-integer or a number past 2^53 in an integer field, a `bigint` or string in a float field, and an `f32` overflow. It wrapped or coerced before. Numbers above 2^53 go as a `bigint`.
- `scheme(...)` and `new Scheme(...)` refuse a `when` or count that names a later field, an unknown id, a field of another scope or (for a count) a bool or float. They also refuse a member name used inside an unanchored group and outside it, and a `repeat` or `times` inside a round. Before, a bad id threw at pack or a `when` never matched.
- The unpacked row has no `""` or flag-byte member. In a round, every name the round can hold is a list with one entry per round, `undefined` for a skipped round (it appended only the rounds that set it). A `sized`, `bits` or `packed` whose count is a field of the same round now unpacks (it failed with `needed 0`).
- A `when` in a round reads only the round's own value (it fell back to a same-named outer value).
- `Scheme.fields` holds copies of the five reference kinds, with `nameById` and the `allFields` parameter of `unpackFields` removed (internal; `index.d.ts` is identical).
- Unpack of a round costs about 8 bytes times the names a round can hold times the packet bytes in memory (1 MB zero packet with a 36-name `when` body: 299 to 313 MB heap, 11 to 19 MB before); linear, not count-driven. Capped by the round limits since loop 15.

**Breaking changes for callers, loop 15** (AZ-2217; pack output and the bytes of every packet within the limits are unchanged):
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 4,194,304 slots together, until the scheme raises the limits with `withLimits`.

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs the three error fields |

**Log format**: none inside the package

**Log storage**: none
