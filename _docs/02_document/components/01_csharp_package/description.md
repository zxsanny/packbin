# C# package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for .NET.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Targets**: `netstandard2.0` and `net10.0` (`TargetFrameworks` in `Packbin.csproj`, committed in `68ca4f8`). `Compat.cs` holds the .NET 10 calls the `netstandard2.0` build lacks (HKDF-SHA256, strict UTF-8 check, `SingleToInt32Bits` and `Int32BitsToSingle`, `Zero`, `Dictionary.TryAdd`): `net10.0` calls the framework, `netstandard2.0` does the same work by hand. The `netstandard2.0` build references `System.Memory` 4.6.3. The test project runs the same suite against both builds (`dotnet test -p:PackbinTarget=netstandard2.0`), and `TargetParityTests` pins the parts where the two use different code. Both targets gave the same results in loop 17 (649 tests each).

**Downstream consumers**: the caller's server. The other language packages do not call this package. They meet at the golden fixture.

## 2. Internal Interfaces

### Interface: Packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme<T>` | type number, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flag byte is not read earlier in the same scope (a nested row is a scope of its own), a ninth bit on one read of a flag byte, a bool or empty group that is not directly in `Flags` or a `FlagByte` bit, a `When` that names a field that is not an earlier one of the same scope, a count (`Sized`, `Bits`, `Packed`, `Times`) that names such a field or one that is not an integer field (`U8` to `I64`) or a `U2` slot, a field declared for another row type, a nested row or a row-typed `List` or `Dict` element whose type has no public parameterless constructor, or a `Repeat` or `Times` inside a `Repeat` or `Times` round (§7) |
| `Field.Flags`, `.Bit` on a `FlagByte`, `Field.Group` | fields | field | No | a ninth member of `Field.Flags(...)`, thrown at the call (a ninth `.Bit(...)` on a `FlagByte` is thrown when the scheme is built, not at `.Bit`); an empty group bound to a member that is not `bool` or `bool?` (§7) |
| `BinaryPacker.Pack` | scheme, row | bytes | No | a dictionary row's number that is not a whole number fitting the field (an `ArgumentException` naming the member); a walked field with no value, a set flags group with a missing value, a `Times` list longer than its count, a lone byte run or list for a name that holds one per round (§7); a count that pack did not write (a `When` skipped it) or that does not fit an `int` throws `ArgumentException` (`count 'N' is missing`) |
| `BinaryPacker.Unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `Repeat` or `Times` round past the scheme's limits; never throws on bytes except for the scheme shapes in §7 (a typed row of a `Repeat` or `Times`, a `Flags` as a direct `List` or `Dict` element, an unsupported collection member) |
| `Scheme<T>.WithLimits`, `MaxRounds`, `MaxSlots`, `BinaryPacker.DefaultMaxRounds`, `DefaultMaxSlots` | `maxRounds` (int), `maxSlots` (long) | a new scheme with those unpack limits | No | `ArgumentOutOfRangeException` for a limit below 1 (§7) |

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

**State Management**: clear pack is stateless. A failed clear unpack does not change the next clear pack. Unpack state lives in one `Scope` per call (`Scope.cs`): the values read in the packet, or in one `repeat`/`times` round, `list` element or `dictionary` value, plus the flag bytes read there. Pack keeps one `Scope` too, called `seen`: the values written so far in the packet, in one round, or in one `list` element or `dictionary` value. A scheme holds no per-call state, so one scheme is shared by threads (two threads, 200 000 unpacks each, in the race test). The scheme owns its fields (loop 13): `SchemeOrder.Resolve` builds copies (`Field.With`, `Condition.Resolved`) with every count and `When` bound to a member name, and the caller's `Field`, `Condition` and `params` array are never changed, so one can be reused by many schemes (many threads on one shared `Condition` in the ownership test). A `FlagByte()` handle holds no bit, and `FlagScopes.Bind` gives every read of it in a scheme a `FlagGroup` of its own, so `flagByte.Bit(x)` after construction does not change a built scheme (AZ-2180, held since AZ-2135 in loop 17); a `Field.Flags(...)` field is shared by reference between the schemes that reuse it and is never changed, so it is not cloned. A session keeps one send counter and one receive counter.

**Source layout** (loop 17): `Packbin.cs` holds `Scheme<T>`, `BinaryPacker` and `SchemeOrder`, which resolves ids, scopes, counts and row types; `Field.cs` and `Fields.cs` are the field factories; `Bound.cs` is the public `Bound<T>` type (a value and an error; it moved out of `ObjectValues.cs`, which is deleted); `PackSession.cs`, `SessionPad.cs` and `Compat.cs` are the session and the `netstandard2.0` shims.
- Typed rows (new in loop 17): `FieldAccess.cs` (`MemberAccess`) compiles the getter and setter of one accessor expression when the field is built; `FieldBinding.cs` holds what a field needs to read and write its member (the accessor, the `u2` slot accessors, the nested row type and constructor, the `CollectionShape` of a `List` or `Dict` member, `Creator`); `RowBinding.cs` reads a row into a `RowValues` (one per row, a nested row's values under its member name) and writes the unpacked values back into a row.
- Construction checks: `FlagScopes.cs` (`Bind`: binds and numbers the split flag bits, one `FlagGroup` per read of a flag byte; replaced `Validate`), `FlagGroup.cs` (the bits of one read, at most eight) and `RoundScopes.cs` (a `Repeat` or `Times` inside a round); the reference, count and row-type checks are `SchemeOrder` in `Packbin.cs`.
- Walkers: `Walker.cs` (field dispatch, flags, `When`, scalars), `Walker.Scalars.cs` (scalar write and read), `Walker.Numbers.cs` (strict dictionary-row numbers, new), `Walker.Counted.cs` (`Sized`, `U2`, `Bits`, `Packed`, `Times`, `Utf8`, `List`, `Dict`, `RequireCount`), `Walker.Elements.cs` (`ElementValue`: the value one list or dict element read, new), `Walker.Presence.cs` (when a flag bit is on, `RequireValue`) and `Walker.Rounds.cs` (pack of the rounds of `Repeat` and `Times`, the names a round holds, lone values and `RequireRoundCollections`, `AppendRound`); `Scope.cs` is the per-call state and holds `RoundBudget`, the round and slot count of one unpack call (loop 15).

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none on `net10.0` | — | the runtime's little-endian primitive writes are enough |
| `System.Memory` | 4.6.3 | `netstandard2.0` build only (`Span`, `BinaryPrimitives`) |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return an error value, never an exception (§7)
- Pack of a set flags group with a missing value throws `ArgumentException` naming it, instead of writing a packet its own unpack rejects (§7)
- Pack of any walked field with no value throws `ArgumentException` naming the member and its field id (`RequireValue` in `Walker.Presence.cs`); only a flag bit may be left clear (§7)
- Pack of a count that was not written, or that does not fit an `int`, throws `ArgumentException` (`RequireCount` in `Walker.Counted.cs`); it was `InvalidOperationException` and a bare `OverflowException` before loop 17
- Pack of a dictionary row's number checks it against the field (`WholeNumber`, `RealNumber`, `SingleNumber` in `Walker.Numbers.cs`): a value that is not a whole number fitting an integer field, or not a number for a float field, throws `ArgumentException` naming the member (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- `u8` to `u32`, `i8` to `i32`, `f32` and `f64` are boxed as `double`; `u64` and `i64` are read exactly and boxed as `ulong` and `long`, so `UnpackResult.Values` holds those types for them (a breaking change for callers that read a 64-bit value straight from `Values`; callers going through the row type are unaffected). Exact types for the other kinds are AZ-2116
- A `Group` as a list or dictionary element unpacks since loop 17 (AZ-2119, see Group elements below). Dictionary-mode `Pack` of the rows it gives still fails (`'A' has no value`): the item is put under the group's name instead of being flattened, so unpack then repack of dictionary rows does not round-trip for group elements (follow-up spec, about 1 point). A `Flags` (or another container with no value of its own) as a direct list or dictionary element still throws `KeyNotFoundException` (key `""`) on unpack, typed and dictionary: this is the `listflags` ring shape, and C# does not take part in that ring (assessment E4, open for the owner)
- A flags group whose only present values sit under a `When`, `Repeat` or `Times` (directly under `Flags` or a flag bit, or inside a group under them) leaves its bit clear and drops them; a `When` directly under combined `Flags` is dropped on pack too (AZ-2120 and the rest of AZ-2128, held). A nested `Flags`, a split flag bit and a `u2` with any slot present count since loop 17 (see Flag group presence)
- A non-null typed nested row whose members are all null leaves a flags group's bit clear and the object is dropped silently; a set group with a null nested row fails naming the row (assessment D2, open for the owner)
- `When(Eq(boolId, false))` never matches: a `false` bool is a clear bit, absent on the wire, and pack now decides the `When` on what it wrote. The row packs `01 00` and reads back; the body is not written. Which kinds a `When` may name (C# takes any value field, Java and C++ integer or bool) is open under AZ-2126: the `When` half of the AZ-2181 owner decision (float, utf8 and bytes refused, a bool only with `true`) is not implemented, and `FloatWhenTests` and `WrittenWhenKindsTests` still assert that a float `When` works. A count is decided: it must name an integer field or a `u2` slot, or the scheme does not build (AZ-2181, loop 17)
- Typed-row `Unpack` of any scheme with a `Repeat` or `Times` throws `InvalidCastException` out of `BinaryPacker.Unpack`, because a typed member holds one scalar. `BinaryPacker.Read` is internal, so no public API reads an aligned round row (AZ-2092)
- A lone `IDictionary` for a `Dict` name in a round is broadcast to every round (it threw `'M' has no value`), and so is a lone `string` for a `Utf8` name; whether a lone dictionary should be refused like a lone collection is open (assessment E5). A lone `IList` for a `List` name stays a list of rounds. An empty `List<int>` or `object[]` for a `Bits` or `Packed` name stays a list of zero rounds, because it cannot be told from no rounds (AZ-2182). A lone non-collection (an `int`) for a `Bytes` or `Sized` name is broadcast and then fails in `PackBytes` with a raw `InvalidCastException`, as it does outside a round (assessment E8, a follow-up of about 1 point)
- A typed collection member that is not an array, a `List<E>`, a `Dictionary<string, E>` or a type those are assignable to (`Stack<int>`, a class derived from `List<E>`) builds and throws out of `Unpack` (assessment D4, review R4: refusing it at construction is open). A member whose element type is narrower than the element field (`List<int>` of `U32` elements) throws `OverflowException` out of `Unpack` for a large value; the same `Convert.ChangeType` call existed in `ObjectValues` (review R1, open for the owner)
- `U2` slots, `Bits` and `Packed` items still round or coerce: a `1.5` in a `U2` slot packs as 2 (assessment E11, follow-up)
- Typed rows are read and written through accessors that `Expression.Compile` builds once per field, so a trimmed or ahead-of-time app (Unity IL2CPP) interprets them; the suite was not run there (assessment D8)
- A list or dictionary element that is a group holding a `Repeat` or `Times` only builds; a group element does not pack per item (AZ-2119)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The exceptions come from the shape of the scheme and are listed in §7 (a typed row of a `Repeat` or `Times`, a `Flags` as a direct `List` or `Dict` element, an unsupported typed collection member). The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In C# it is a `ShortPacket(field, 0, left)` built by one helper, `InterimBadValue` in `Walker.Counted.cs`, so C15 changes one method. Absent or negative counts, invalid UTF-8 and zero-width `times`, `list` and `dict` rounds use it; the `repeat` case returns `TrailingBytes`. Counts are read as `long` and compared with the bytes left before any allocation; a `u64` above `long.MaxValue` is clamped and then fails as a short packet. A float in a `when` compares as a double by Java's rule: NaN equals NaN, `-0.0` differs from `0.0`, and the comparison never throws (it threw `OverflowException` for a condition value out of decimal range).

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, one `list` or `dict` element, or (loop 17) one nested row. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. A nested row (`Field.Group(accessor, ...)`, no anchor) starts with no flag byte visible and a byte read inside it stays inside it; an anchored group shares the bytes around it. `Packbin.cs` `SchemeOrder.Resolve` runs `FlagScopes.Bind`; a violation is an `ArgumentException` (`flag bit 'A' has no flag byte read before it in its scope`). `[m, Group(g, m.Bit(x))]` and `[Group(g, m, ...), m.Bit(x)]` built before loop 17, because the members of a nested row were merged into flat names, and are refused now (AZ-2092; the same rule as Java, AZ-2233).

**Split-bit numbering** (loop 17, AZ-2135; `FlagScopes.cs`, `FlagGroup.cs`). A split-form bit is numbered by its place among the bits that follow one read of its flag byte, as in Rust, C++, TypeScript, Java and Python. The `FlagByte()` handle holds no bit and no scheme owns it: `Bit(field)` only makes a bit with no number, and `FlagScopes.Bind` gives each read of the handle in a scheme a `FlagGroup` of its own (`Reserve` takes the next number, `Place` stores the bound inner field), so any number of schemes can share the handle and a second read of it starts its own bits. One read holds at most eight bits; the ninth fails in `new Scheme<T>(...)` with `flag bit 'A8': one flags byte holds at most 8 bits`. A bit that is created and never placed in a scheme no longer takes a number. The combined `Field.Flags(...)` numbers its members by position and still refuses its ninth member when `Field.Flags(...)` is called (`FlagGroup.AddBit`). Three probes (a row with `A`, `B`, `X` as `byte?`), before and after: one handle in two schemes, `[m, m.Bit(u8 x)]` with `x` = 5, `01 03 05` and now `01 01 05` in both; `[m, early a, late b]` (the late bit created first) with `b` = 9, `01 01 09` and now `01 02 09`; `[m, m.Bit(a), m, m.Bit(b)]` with only `b` = 9, `01 02 02 09` and now `01 00 01 09`. A scheme whose bits were built in order on a handle of its own packs the same bytes as before (batch 1 differential, 21 schemes by 20 000 seeds: no byte differed from the previous build run with one handle per read).

**Bool rule** (loop 12). A `bool` or an empty group is a flag bit with no payload. It is allowed only directly in `Flags` or as the field of a `FlagByte` bit; anywhere else (top level, a group with fields, `When`, `Repeat`, `Times`, a list or dict element) `SchemeOrder.Walk` throws `ArgumentException`. Its bit is set only for `true`: `false`, no value, and any other value (`1` or `"true"` in a dictionary row) leave it clear. Unpack stores `true` only under a set bit; a clear bit leaves the member at its default (`false`, or `null` for `bool?`). An empty group must bind a `bool` or `bool?` member: on any other member (a nested row, `byte?`, `string`) its bit could never be set, so the `Field.Group` factory throws `ArgumentException` before `new Scheme<T>` runs. A ninth child of `Field.Flags(...)` throws `ArgumentException` in `FlagGroup.AddBit`, when `Field.Flags(...)` is called. A ninth bit after one read of a `FlagByte` throws it when the scheme is built (`FlagGroup.Reserve`, called from `FlagScopes.Bind`), not at `.Bit(...)` (loop 17, AZ-2135; see Split-bit numbering).

**Flag group presence** (`Walker.Presence.cs`). A group with fields under a flag bit is on when its own member is not null or any value-bearing child has a value: numbers, bytes, strings, lists, dicts, `U2`, `Sized`, `Bits`, `Packed`, and nested groups at any depth. Since loop 17 (AZ-2128) a nested `Flags` and a split flag bit child count too (`ChildPresent` follows `Flags` into its bits and a `FlagBit` into its field), and a `U2` is on when any of its slots has a value (`AnyPresent`; it looked at the first slot name only, so `Flags(U2((0, A), (1, B)))` with only `B` packed `01 00` and dropped it, and fails now naming the missing slot). `Flags(0, Group(0, Mark, Flags(0, U8 B)))` with `B` = 5 packs `01 01 01 05` (it packed `01 00`). With a required `U8 C` added to the group: `B` = 5 and `C` left out fails `'C': flag group 'Mark' is set, so it needs a value` (it packed `01 00`), `B` = 5 and `C` = 7 pack `01 01 01 05 07`, only `C` = 7 packs `01 01 00 07`, and nothing set packs `01 00`. A nested row's presence is what is inside it, not whether its member is non-null (`ScopeOf`). A `When`, `Repeat` or `Times` directly under `Flags` or a flag bit, or inside a group under them, still gives no presence (held). A set group is written in full, so pack throws `ArgumentException` naming the first missing value, also inside a nested group; for a null nested row it names the nested row, not its first child.

**Reference scope** (loop 13, `SchemeOrder.Walk` in `Packbin.cs`). A `When` condition and the count of `Sized`, `Bits`, `Packed` and `Times` name a field id. The walk binds each one to the member name of that id from the scope walked so far. Ids still number straight through `Repeat` and `Times` bodies, but a reference finds only the fields its own scope already holds. A scope is the top level, one `Repeat` or `Times` body, one `List` or `Dict` element, or one nested row; `Flags`, `When` and a continuing group share their parent's. A later field, an id nobody declared, an outer field from inside a body, or a field of an earlier body is an `ArgumentException` naming the referring and the referenced id. Pack and unpack read the bound name, so no id is looked up per call.

**Counts** (loop 17, AZ-2181; `SchemeOrder.Count` in `Packbin.cs`, `RequireCount` in `Walker.Counted.cs`). A count of `Sized`, `Bits`, `Packed` or `Times` must name an integer field (`U8` to `I64`, which is that run of the `Field.Kind` enum) or a `U2` slot. A float, bool, string or byte-run count is an `ArgumentException` when the scheme is built, naming the counted field and the field it counts by (`'Out' (field id 1): its count names 'S' (field id 0), a utf8 field; a count must name an integer field`; `times 2: ...` for a `Times`). A float count built before and failed later, so float counts and the hostile float-count packets (NaN, an infinity, a huge value) that the unpack tests used to send cannot reach unpack now; those six `HostileUnpackTests` cases assert the construction error instead (owner decision of 2026-10-06, which reverses C# AZ-2088 AC-6). A `When` may still name any value field. At pack a count that `seen` does not hold, or that does not fit an `int`, is an `ArgumentException` (`Data: count 'N' is missing`; `Data: count 'N' is 4294967296, which does not fit an int`); it was an `InvalidOperationException` and a bare `OverflowException`. A count above the bytes left still ends in a short packet on unpack, as before.

**Row type check** (loop 13, `RequireRow`). A field declared for another row type (`Field.U16<Other>` in a `Scheme<T>`) is an `ArgumentException` naming both types, because values are found by member name and the field would be left out silently. A field declared for a base type of `T` is allowed. A `List` or `Dict` element and a nested row bind their own row types, so they are not checked against the outer one. A child-row field used directly in the parent scheme is refused too, and so is the decoy-row hack (declaring round fields on another row type to receive lists).

**Typed rows** (loop 17, AZ-2092; `RowBinding.cs`, `FieldBinding.cs`, `FieldAccess.cs`). Typed `Pack` and `Unpack` walk a row through the accessor each field was declared with. `ObjectValues` (reflection over every public member, with the members of nested rows merged into one flat set of names) is deleted.
- Scope: `RowBinding.Read` gives one `RowValues` per row, and a nested row's values sit under its member name in a `RowValues` of their own, so a nested row never sees the members of the row around it and a `Name` on both no longer overwrites (`Name` 1 and `Inner.Name` 2 pack `01 01 02`). The dictionary overloads of `Pack` keep one flat dictionary; `Walker` tells the two apart by type (`values is RowValues`, `Scope.Scoped`), in six places (review R5: a design note for the next walker change).
- Accessors: `MemberAccess.From` compiles the getter and the setter of one accessor with `Expression.Compile` when the field is built, once per field (a `U2` has one per slot; a nested row, and a list or dict member, also compile a `new` for the row, the collection and the element row), so a call reads and writes members with no reflection. A property with a private setter and a public field bind; a read-only member is refused. The setter assigns a value of the member's own type as it is, casts a `double` read to a member of the field's own width (exact), and sends any other number through `Convert.ChangeType`.
- Elements: pack reads an item of a `List` or `Dict` through the element field's accessor when the item is of the element field's row type (`RowBinding.Element`), and takes any other item as the element's value itself. Unpack decides by the collection member's declared element type (`CollectionShape.RowElements`): it builds element rows when the member is declared for them (`List<Role>` for `Utf8<Role>`) and stores values when it is not (`ushort[]` for `U16<El>`, `List<object?>`). The two rules differ on purpose: a `List<object>` that holds row objects packs and unpacks as raw values.
- Collection members unpack as an array, `List<E>`, `Dictionary<string, E>`, or a type those are assignable to (`IList<E>`, `IReadOnlyList<E>` and so on); other types are in §7.
- Constructors: unpack creates a nested row and each element row of a `List` or `Dict` with a compiled `new` (`Creator.Of`), which needs a public parameterless constructor on a class. `SchemeOrder.RequireCreatable` refuses a nested row type or an element row type without one when the scheme is built: `'Inner': row type NoCtor needs a public parameterless constructor to be unpacked`.
- Pack errors that name the nested row: an absent nested row outside `Flags` is `'Inner' has no value; a field that may be absent belongs in Flags`, and a set `Flags` group with a null nested row is `'Inner': flag group 'Mark' is set, so it needs a value`. Both are `ArgumentException`, as before; the second named the group's first child before (batch 1, discovery 7).
- Typed `times`: a scalar member in a `Times` round is packed in every round (the rounds after the first threw `has no value`).

**Group elements** (loop 17, AZ-2119; `Walker.Elements.cs`). A `List` or `Dict` whose element is a `Group` threw `KeyNotFoundException` on unpack, because the element read stored no value under the group's name. `ElementValue` now takes the scope that holds the group's fields as the element (a row keyed by the member names, the shape the other packages return), except for a typed nested row, which is stored whole under its member name, and an empty group, which is a bool. The dictionary form of an unpacked row holds the internal `Scope` instance (a `Dictionary<string, object?>`), as the top-level result already did, with no wrapper under the group's name. Typed rows get one element row per item for a nested-row group and for an anchored group (`ApplyField` into the new element). Typed anchored group elements threw `KeyNotFoundException` too before. Limits are in §7: dictionary-mode `Pack` of the rows, and a `Flags` as a direct element.

**Strict numbers** (loop 17, AZ-2191; `Walker.Numbers.cs`). A dictionary row holds boxed values of any type, so each is checked against the field it is written to. An integer field takes a whole number that fits its width: any integer type, or a finite `double`, `float` or `decimal` that has no fraction (a double beyond `long.MinValue`..`ulong.MaxValue` is refused; 2^63 is accepted for `U64` and refused for `I64`; -0.0 is accepted). A fraction, NaN, an infinity, a bool, a string, a `char`, an enum, an `object` or a number out of range throws `ArgumentException` naming the member (`U8: 300 does not fit in u8`, `U8: expected a number for u8, got Boolean`). A float field takes any number type; a bool, string, `char`, enum or object is refused, and so is a finite value beyond `f32`; NaN and the infinities are written as given. It used to round a fraction, coerce a bool or string, convert a `char` (`'a'` became 97) or an enum to its number through `IConvertible` (assessment E9: open for the owner, the other packages have no `char` or enum types), and throw `OverflowException`, `FormatException` or `InvalidCastException`. No value that packed before packs to other bytes. `U2` slots, `Bits` items and `Packed` items are not checked this way (§7).

**Rounds** (loop 13, `Walker.Rounds.cs`). A `Repeat` or `Times` round is addressed by index. The names a round can hold are its own fields and those under `When`, `Flags`, flag bits and groups (`RoundNames`). Pack reads item i of each name's list for round i, through `When`, `Flags`, flag bits and groups. A `Repeat` runs as many rounds as its longest list; a `Times` runs its borrowed count and throws when a list holds more items than the count (`RequireNoExtraRounds`). A list that ran out for an optional name is a skipped round; for a required one, `RequireValue` throws. Unpack gives every name a round can hold one list entry per round, `null` for a round that skipped it (`AppendRound`), and zero rounds leave the keys absent, so a repack gives the same bytes. `RoundScopes.cs` refuses a `Repeat` or `Times` inside a round, directly or under `When`, `Flags`, a flag bit or a group (a nested row included); a `List` or `Dict` element starts outside any round. The message names the nested container.

**Lone values in a round** (loop 17, AZ-2182; `SliceRound`, `RequireRoundCollections`, `IsOneCollection`). A value that is not a list goes to every round, where it went to round 0 only. A lone scalar under `Flags` or a flag bit therefore sets the bit in every round: `Repeat(0, Flags(0, U8 A), U8 B)` with `A` = 5 and `B` = [1, 2] packed `01 01 05 01 00 02` and packs `01 01 05 01 01 05 02` (103 cases of the batch 2 differential changed bytes this way; the Rust map `times` gives a lone scalar to round 0 only according to batch 2 discovery 6, a follow-up with no ticket yet). A lone `IDictionary` for a `Dict` name and a lone `string` for a `Utf8` name go to every round too. A name that holds a byte run or a list per round (`Bytes`, `Sized`, `Bits`, `Packed`) takes a list with one entry per round, because one `byte[]` or list alone would be read as the list of rounds: `RequireRoundCollections` refuses a lone `byte[]` and a list whose first non-null item is not a list, with an `ArgumentException` that names the field and says to wrap the value in a list. An empty lone `byte[]`, which meant zero rounds (`01`), is refused too; an empty `List<int>` or `object[]` for `Bits` or `Packed` stays a list of zero rounds. A typed row's `Bytes` member in a round is always refused, because it can only be a lone `byte[]` (it threw `InvalidCastException`). Lists of different lengths still throw naming the short one.

**Round limits** (loop 15, AZ-2216; `Scope.cs`, `Packbin.cs`). A scheme carries `MaxRounds` (default `BinaryPacker.DefaultMaxRounds`, 65 535) and `MaxSlots` (default `DefaultMaxSlots`, 4 194 304). `Scheme<T>.WithLimits(maxRounds, maxSlots)` returns a new scheme over the same fields; an omitted argument is the default, not the receiver's value, so two chained calls drop the first. A limit below 1 throws `ArgumentOutOfRangeException`; there is no unlimited value. `BinaryPacker.ReadFields` gives each call one `RoundBudget` (never static) that every scope of the call shares (the round, `List` element and `Dict` value scopes it opens). `Walker.UnpackRepeat` and `Walker.UnpackTimes` call `TryStartRound(roundsStarted, slots)` before a round's bytes are read, where `slots` is the count of distinct `RoundNames` (`SlotsPerRound`). The round that would be the 65 536th of one field, or would take the slot total past `MaxSlots`, returns `InterimBadValue(field.Name, left)`: no row, no handler call. A `Times` count is not refused up front, so a huge count over few bytes still ends in a short read. A round scope can hold keys outside `RoundNames` (a named flag byte); the slot count does not include them. Not covered by a test: a `List` or `Dict` element that holds a round (AZ-2119).

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
- A count that names a field a `When` skipped throws `InvalidOperationException` (`count 'N' is missing`); the other pack failures are `ArgumentException`. (Loop 17: it is an `ArgumentException` now.)
- A float `When` never throws; NaN equals NaN and `-0.0` differs from `0.0`. An `F32` field with a double-literal condition (`Eq(0, 0.1)` against `0.1f`) now matches on neither side; it matched on pack and not on unpack.
- A scheme copies its fields; the caller's `Field` and `Condition` objects are no longer bound or changed.
- Unpack of a round is about packet bytes times the names in the round in memory and time (337 MB heap for a 1 MB packet with a 36-name `When` body, 57 MB before); linear, bounded by the scheme. Capped by the round limits since loop 15.

**Breaking changes for callers, loop 15** (AZ-2216; pack output and the bytes of every packet within the limits are unchanged):
- Unpack refuses a packet whose `Repeat` or `Times` starts more than 65 535 rounds, or whose rounds hold more than 4 194 304 slots together, until the scheme raises the limits with `WithLimits`.

**Breaking changes for callers, loop 17** (the public API is unchanged: reflection dumps of the public and protected members of `Packbin.dll` before and after each stage are identical on both targets; the bytes of schemes and rows not named below are unchanged):
- Typed rows: a nested row no longer shares names with the row around it; a nested row type, or the row type of a `List` or `Dict` element, without a public parameterless constructor is refused at construction; a flag byte read in a nested row stays inside it (`[m, Group(g, m.Bit(x))]` and `[Group(g, m, ...), m.Bit(x)]` are refused); the pack error texts of an absent nested row and of a set group with a null nested row changed.
- Split bits are numbered by field order per read of the flag byte: a handle shared by two schemes, a bit created before an earlier one is placed, and a flag byte read twice pack other bytes (`01 03 05` to `01 01 05`, `01 01 09` to `01 02 09`, `01 02 02 09` to `01 00 01 09`); the ninth bit fails at construction, not at `.Bit(...)`; a bit created and never placed takes no number.
- Presence: a nested `Flags`, a split flag bit child and a `U2` with any slot present set the group's bit, so values that were dropped are written; a set group with a missing value, and a `U2` with only a non-first slot, fail pack naming the value (`01 00` before).
- Counts: a count of `Sized`, `Bits`, `Packed` or `Times` that names a float, bool, string or byte run is refused at construction (`ArgumentException`); a count that pack did not write or that does not fit an `int` is an `ArgumentException` (`InvalidOperationException` and a bare `OverflowException` before). Six hostile float-count unpack tests and three `WrittenCountTests` sites were changed by owner decision (2026-10-06).
- Rounds: a lone scalar goes to every round, so a scalar under `Flags` or a flag bit sets the bit in every round (`01 01 05 01 00 02` to `01 01 05 01 01 05 02`); a lone `byte[]` or list for a `Bytes`, `Sized`, `Bits` or `Packed` name, and an empty lone `byte[]`, throw `ArgumentException`; a lone dictionary for a `Dict` name and a lone string for a `Utf8` name are broadcast (a lone dictionary threw `'M' has no value`); a typed `Times` row packs in every round (245 differential cases threw `has no value`); a typed `Bytes` member in a round is refused.
- Group elements: a `List` or `Dict` of groups unpacks (it threw `KeyNotFoundException`), in typed rows (nested-row and anchored groups) and in the dictionary form.
- Dictionary rows pack numbers strictly: a fraction, NaN, an infinity, a bool, a string, a `char`, an enum, an `object` or a number out of range for an integer field, and a non-number or an `f32` overflow for a float field, throw `ArgumentException` naming the member (`OverflowException`, `FormatException`, `InvalidCastException`, a rounded fraction or a coerced value before). `U2` slots, `Bits` and `Packed` items are unchanged.
- Speed: typed `Pack` and `Unpack` run about 2x faster (members through accessors compiled once per field, no reflection per call).

**Potential race conditions**:
- Clear pack keeps no packet. A dropped session payload desynchronizes that direction. There is no tag.

**Performance bottlenecks**:
- AC-10 is the bound: 100000 position round trips ≤ 1 second on one core (163 ms per 100 000 typed round trips after loop 13). Since loop 17 (AZ-2093) the AC-10 test, `Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond`, times only the public `Pack(Target, row)` and `Unpack(bytes, Target.On(...))`; the bound is unchanged at 1.0 s, and the test takes the fastest of three passes (review R3, open for the owner)
- Typed binding through compiled accessors (AZ-2092) made the typed round trip about 2x faster. The loop 17 perf run (`_docs/03_implementation/perf_run_loop17_report.md`, one macOS arm64 laptop, `68ca4f8` against `412ae3a`, 100 000 public typed round trips): standalone Release cold first pass 564 to 570 ms to 266 to 274 ms (2.1x), best warm pass 146 to 147 ms to 62 to 63 ms (2.3x); the AC-10 test 641 to 656 ms to 319 to 343 ms in Release and 791 ms to 326 to 346 ms in Debug (batch 1 worker: 2.0x cold, 2.6x warmed). The spec's AC-7 asked for 3x and at most 300 ms and is partly met (the cold standalone pass is under 300 ms, 3x is not; assessment D11, open for the owner: accept and amend AC-7, or spec a typed walker that does not go through a dictionary; the engine alone costs about 130 ms cold). These are measurements, not a promise
- The AC-10 test passes with a thin margin inside the full container suite: xunit runs test classes in parallel and `PackbinTests` has no collection that disables it, so the same test used 786 ms on `net10.0` and about 1 s on the `netstandard2.0` run there (340 to 390 ms alone), and the retry of a pass above 1.0 s keeps it green (perf run report, review R3)
- Every integer scalar on pack goes through a decimal range check (`WholeNumber` in `Walker.Numbers.cs`), even when the boxed value already has the field's width; the gain from a fast path is unmeasured (review R2, decide with D11)

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
