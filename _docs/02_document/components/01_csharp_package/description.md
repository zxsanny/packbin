# C# package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for .NET.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's server. The other language packages do not call this package. They meet at the golden fixture.

## 2. Internal Interfaces

### Interface: Packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme<T>` | type number, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flag byte is not read earlier in the same scope, a bool or empty group that is not directly in `Flags` or a `FlagByte` bit, a `When` or count that names a field that is not an earlier one of the same scope, a field declared for another row type, or a `Repeat` or `Times` inside a `Repeat` or `Times` round (§7) |
| `Field.Flags`, `.Bit` on a `FlagByte`, `Field.Group` | fields | field | No | a ninth bit on one flags byte; an empty group bound to a member that is not `bool` or `bool?` (§7) |
| `BinaryPacker.Pack` | scheme, row | bytes | No | integer does not fit; a walked field with no value, a set flags group with a missing value, a `Times` list longer than its count (§7); a count whose field pack did not write (a `When` skipped it) throws `InvalidOperationException` |
| `BinaryPacker.Unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never throws on bytes (see §7) |

**Input DTOs**:

```
Value:
  fields: name to integer, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: int — sum of present field widths
ShortPacket:
  field: string
  needed: int
  left: int
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `Start` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `Join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `Pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `Unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache. The call does not store the packet.

**Seed data**: the golden hex file.

**Rollback**: unlist the NuGet version. The library has no schema migration.

## 5. Implementation Details

**State Management**: clear pack is stateless. A failed clear unpack does not change the next clear pack. Unpack state lives in one `Scope` per call (`Scope.cs`): the values read in the packet, or in one `repeat`/`times` round, `list` element or `dictionary` value, plus the flag bytes read there. Pack keeps one `Scope` too, called `seen`: the values written so far in the packet, in one round, or in one `list` element or `dictionary` value. A scheme holds no per-call state, so one scheme is shared by threads (two threads, 200 000 unpacks each, in the race test). The scheme owns its fields (loop 13): `SchemeOrder.Resolve` builds copies (`Field.With`, `Condition.Resolved`) with every count and `When` bound to a member name, and the caller's `Field`, `Condition` and `params` array are never changed, so one can be reused by many schemes (many threads on one shared `Condition` in the ownership test). `FlagGroup` is still shared: `flagByte.Bit(x)` after construction changes a built scheme (AZ-2180). A session keeps one send counter and one receive counter.

**Source layout** (loop 13): `Packbin.cs` `SchemeOrder` resolves ids, scopes and row types; `FlagScopes.cs` and `RoundScopes.cs` are the construction checks for flag bits and for rounds inside rounds; `Walker.cs`, `Walker.Counted.cs`, `Walker.Presence.cs` and `Walker.Scalars.cs` are the pack and unpack walkers; `Walker.Rounds.cs` (new) packs and unpacks the rounds of `Repeat` and `Times`; `Scope.cs` is the per-call state.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime's little-endian primitive writes are enough |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return an error value, never an exception (§7)
- Pack of a set flags group with a missing value throws `ArgumentException` naming it, instead of writing a packet its own unpack rejects (§7)
- Pack of any walked field with no value throws `ArgumentException` naming the member and its field id (`RequireValue` in `Walker.Presence.cs`); only a flag bit may be left clear (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- `u8` to `u32`, `i8` to `i32`, `f32` and `f64` are boxed as `double`; `u64` and `i64` are read exactly and boxed as `ulong` and `long`, so `UnpackResult.Values` holds those types for them (a breaking change for callers that read a 64-bit value straight from `Values`; callers going through the row type are unaffected). Exact types for the other kinds are AZ-2116
- A `Group` as a list or dictionary element throws `KeyNotFoundException` on unpack (AZ-2119). A `When` directly under combined `Flags` is dropped on pack (AZ-2120)
- A flags group whose only present values sit under a nested `Flags`, a split bit, `When`, `Repeat` or `Times` leaves its bit clear and drops them (AZ-2128)
- `When(Eq(boolId, false))` never matches: a `false` bool is a clear bit, absent on the wire, and pack now decides the `When` on what it wrote. The row packs `01 00` and reads back; the body is not written. Which kinds a `When` or a count may name (C# takes any value field, Java and C++ integer or bool) is open under AZ-2126; a count that names a non-integer field builds and fails at pack (AZ-2181)
- Typed-row `Unpack` of any scheme with a `Repeat` or `Times` throws `InvalidCastException` out of `BinaryPacker.Unpack`, because a typed member holds one scalar. `BinaryPacker.Read` is internal, so no public API reads an aligned round row (AZ-2092)
- A lone scalar for a name in a round goes to round 0 only (Java and TypeScript broadcast it), and a lone `byte[]` or non-`IList` collection is read as a list of rounds (AZ-2182)
- A list or dictionary element that is a group holding a `Repeat` or `Times` only builds; a group element does not pack per item (AZ-2119)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In C# it is a `ShortPacket(field, 0, left)` built by one helper, `InterimBadValue` in `Walker.Counted.cs`, so C15 changes one method. Absent or negative counts, invalid UTF-8 and zero-width `times`, `list` and `dict` rounds use it; the `repeat` case returns `TrailingBytes`. Counts are read as `long` and compared with the bytes left before any allocation; a `u64` above `long.MaxValue` is clamped and then fails as a short packet. A float in a `when` compares as a double by Java's rule: NaN equals NaN, `-0.0` differs from `0.0`, and the comparison never throws (it threw `OverflowException` for a condition value out of decimal range).

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `Packbin.cs` `SchemeOrder` runs `FlagScopes.Validate`; a violation is an `ArgumentException`.

**Bool rule** (loop 12). A `bool` or an empty group is a flag bit with no payload. It is allowed only directly in `Flags` or as the field of a `FlagByte` bit; anywhere else (top level, a group with fields, `When`, `Repeat`, `Times`, a list or dict element) `SchemeOrder.Walk` throws `ArgumentException`. Its bit is set only for `true`: `false`, no value, and any other value (`1` or `"true"` in a dictionary row) leave it clear. Unpack stores `true` only under a set bit; a clear bit leaves the member at its default (`false`, or `null` for `bool?`). An empty group must bind a `bool` or `bool?` member: on any other member (a nested row, `byte?`, `string`) its bit could never be set, so the `Field.Group` factory throws `ArgumentException` before `new Scheme<T>` runs. A ninth bit on one flags byte (a ninth child of `Flags`, or a ninth `.Bit(...)` on a `FlagByte`) throws `ArgumentException` in `FlagGroup.AddBit`.

**Flag group presence** (`Walker.Presence.cs`). A group with fields under a flag bit is on when its own member is not null or any value-bearing child has a value: numbers, bytes, strings, lists, dicts, `U2`, `Sized`, `Bits`, `Packed`, and nested groups at any depth. A set group is written in full, so pack throws `ArgumentException` naming the first missing value, also inside a nested group.

**Reference scope** (loop 13, `SchemeOrder.Walk` in `Packbin.cs`). A `When` condition and the count of `Sized`, `Bits`, `Packed` and `Times` name a field id. The walk binds each one to the member name of that id from the scope walked so far. Ids still number straight through `Repeat` and `Times` bodies, but a reference finds only the fields its own scope already holds. A scope is the top level, one `Repeat` or `Times` body, one `List` or `Dict` element, or one nested row; `Flags`, `When` and a continuing group share their parent's. A later field, an id nobody declared, an outer field from inside a body, or a field of an earlier body is an `ArgumentException` naming the referring and the referenced id. Pack and unpack read the bound name, so no id is looked up per call.

**Row type check** (loop 13, `RequireRow`). A field declared for another row type (`Field.U16<Other>` in a `Scheme<T>`) is an `ArgumentException` naming both types, because values are found by member name and the field would be left out silently. A field declared for a base type of `T` is allowed. A `List` or `Dict` element and a nested row bind their own row types, so they are not checked against the outer one. A child-row field used directly in the parent scheme is refused too, and so is the decoy-row hack (declaring round fields on another row type to receive lists).

**Rounds** (loop 13, `Walker.Rounds.cs`). A `Repeat` or `Times` round is addressed by index. The names a round can hold are its own fields and those under `When`, `Flags`, flag bits and groups (`RoundNames`). Pack reads item i of each name's list for round i, through `When`, `Flags`, flag bits and groups. A `Repeat` runs as many rounds as its longest list; a `Times` runs its borrowed count and throws when a list holds more items than the count (`RequireNoExtraRounds`). A list that ran out for an optional name is a skipped round; for a required one, `RequireValue` throws. Unpack gives every name a round can hold one list entry per round, `null` for a round that skipped it (`AppendRound`), and zero rounds leave the keys absent, so a repack gives the same bytes. `RoundScopes.cs` refuses a `Repeat` or `Times` inside a round, directly or under `When`, `Flags`, a flag bit or a group (a nested row included); a `List` or `Dict` element starts outside any round. The message names the nested container.

**Pack reads what it wrote** (loop 13, `Walker.cs`, `Walker.Counted.cs`). Pack decides every `When` and reads every count of `Sized`, `Bits`, `Packed` and `Times` from `seen`, as unpack reads what it read. A `When` that names a field an earlier `When` skipped does not match, so pack no longer returns bytes its own unpack rejects or misreads. A flag-bit bool is written to `seen` only when its bit is set, so `Eq(bool, false)` never matches. A count written in an earlier round does not count in the next one.

**Breaking changes for callers, loop 11** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers, loop 12**:
- A `bool` or empty group that is `false` packs a clear bit (`01 00`, was `01 01`), as in Java and Python. Mixed C# versions disagree on `false` until both sides upgrade.
- A `bool` or empty group outside a flag bit is refused at construction. It never round-tripped: it packed 0 bytes and always unpacked `true`.
- A ninth flag bit is refused. It was dropped without an error.
- An empty group bound to a member that is not `bool` or `bool?` is refused in `Field.Group`.
- A flags group whose only values are `U2`, `Sized`, `Bits`, `Packed` or a nested group sets its bit and writes them. They were dropped.
- Pack of a set flags group with a missing value throws. It wrote a packet its own unpack rejected.

**Breaking changes for callers, loop 13** (bytes of a packet that was readable are unchanged):
- Pack throws `ArgumentException` for a walked field with no value, a ragged `Repeat` that leaves a required value out of a round, and a `Times` list longer than its count. It returned a shorter packet before.
- A `When` or count that names a later, outer, undeclared or earlier-body field is refused at construction. A `Repeat` or `Times` inside a round is refused at construction. A field declared for another row type, including a child-row field in the parent scheme and the decoy-row hack, is refused at construction.
- Pack reads each value by round index, also through `When`, `Flags`, flag bits and groups (it dropped them), and unpack returns one list entry per round with `null` for a skipped round.
- A `When` is decided on what pack wrote. A packet that was unreadable or misread now packs the readable form: `Eq(bool, false)` with a clear bit packs `01 00` (it packed the body, `01 00 05`).
- A count that names a field a `When` skipped throws `InvalidOperationException` (`count 'N' is missing`); the other pack failures are `ArgumentException`.
- A float `When` never throws; NaN equals NaN and `-0.0` differs from `0.0`. An `F32` field with a double-literal condition (`Eq(0, 0.1)` against `0.1f`) now matches on neither side; it matched on pack and not on unpack.
- A scheme copies its fields; the caller's `Field` and `Condition` objects are no longer bound or changed.
- Unpack of a round is about packet bytes times the names in the round in memory and time (337 MB heap for a 1 MB packet with a 36-name `When` body, 57 MB before); linear, bounded by the scheme, accepted without a cap.

**Potential race conditions**:
- Clear pack keeps no packet. A dropped session payload desynchronizes that direction. There is no tag.

**Performance bottlenecks**:
- AC-10 is the bound: 100000 position round trips ≤ 1 second on one core (163 ms per 100 000 typed round trips after loop 13)

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs `field`, `needed`, and `left` |

**Log format**: none inside the package

**Log storage**: none
