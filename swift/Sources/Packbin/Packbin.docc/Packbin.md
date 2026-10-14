# ``Packbin``

Pack rows into bytes and unpack them, with the same bytes as the C#, TypeScript, Python, Rust, C++,
Java and Go packages.

## Overview

Both sides keep the same field list; the bytes are only the values. The first byte of a packet is the
scheme's type number, and `unpack` picks the scheme by it.

```swift
import Packbin

let position = try Scheme(0x40,
    .u16(0, "sid"),
    .i32(1, "lat"),
    .i32(2, "lon"),
    .u8(3, "profile"),
    .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))

let raw = try pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
// raw is 40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
let row = try unpackMap(raw, position)
```

### Schemes and fields

A scheme is a type number (0...255) and fields numbered by order from 0. The ids are not written.
Every field has a name: the key of its value in the map form of a row. A refused scheme throws a
``PackbinError`` of kind ``PackbinError/Kind/schemeError`` naming the field id: a gap, a repeated or
negative id, an anchor that is not the next id, a `bool` or an empty group anywhere but directly under
`flags` or a flag byte's bit, a flag bit whose byte is not read earlier in the same scope, a ninth bit
of one flag byte, a name declared twice in one row (the branches of a `when` chain may share one), and
a `when` whose `eq` names a field that is not an earlier integer or bool of the same scope, a bool with
anything but `true`, or an integer with a value it can never hold.

### Groups

`.group(anchor, name, members...)` puts its members under one name. The members share the ids and the
scope of the fields around the group (the anchor is the next id and is not written, and a `when` on
either side may name a field on the other), and their names belong to the row around it. In a map row
the members are a `[String: Any]` under the group's name, on pack and on unpack:

```swift
let scheme = try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "b")))
let raw = try pack(scheme, ["a": 1, "g": ["b": 2]])   // 01 01 02
let row = try unpackMap(raw, scheme)                  // ["a": 1, "g": ["b": 2]]
```

A member's value is read from the group's map only: `["a": 1, "b": 2]` is refused naming `b`, where
TypeScript packs a flat key (owner ruling Go-4 A, as Go). Under `flags` or a flag bit the group's bit is
set when the group is given (an empty map too). A group with no members is a mark, as `bool`: `true`
sets its bit, it stands only directly under `flags` or a flag byte's bit, and the field after it takes
the anchor's id (`.flags(0, .group(0, "mark")), .u8(0, "n")`). In a typed row the group is bound to a
member of a ``PackbinRow`` type (or an optional of one, `nil` being no value) whose members the group's
fields are bound to; a mark is bound to a `Bool`.

A group without an anchor, `.group(name, members...)`, is a nested row: its members are numbered from
0, have references and names of their own (so they may repeat a name of the row around it), and it
takes no id of that row. It is a `[String: Any]` under its name both ways too, and a flat key that
names one of its members while the group is not given is refused:

```swift
let scheme = try Scheme(1, .u8(0, "mode"), .group("in", .u8(0, "mode"), .u8(1, "x")))
let raw = try pack(scheme, ["mode": 1, "in": ["mode": 2, "x": 3]])   // 01 01 02 03
```

TypeScript flattens such a group into the row and refuses names it shares with the row around it; Go
and C# give a nested row its own scope, as Swift does.

### Strings, lists and dicts

`.utf8(id, name)` is a `String`: a u16 byte count (at most 65 535), then the UTF-8 bytes. Unpack refuses
bytes that are not valid UTF-8 (a short packet with `needed` 0 and the bytes left where the string
starts), never repairs them, and keeps a byte order mark.

`.list(name, element)` is a u16 count (at most 65 535), then the items; `.dict(name, element)` a u16
pair count, then each key (as `utf8`) and its item. A list or dict has no id; its element is one field,
a scope of its own with ids from 0: an integer, a float, fixed bytes, `utf8`, another list or dict, a
nested row, or `flags` (an item is then a row, as a nested row's). An anchored group, a `u2`, a flag
byte and a `repeat` are refused as elements. Dict keys are written in unsigned UTF-8 byte order, not
in Swift's `String` order, so a dictionary packs to the same bytes whatever its order, and a key is never
a member of the row:

```swift
let scheme = try Scheme(1, .utf8(0, "name"), .list("xs", .u16(0, "x")), .dict("m", .u8(0, "v")))
let raw = try pack(scheme, ["name": "uav", "xs": [1, 2], "m": ["b": 1, "a": 2]])
// 01 03 00 75 61 76 02 00 01 00 02 00 02 00 01 00 61 02 01 00 62 01
```

In a map row a list is any array but a `[UInt8]` (a byte run, never a list) and a dict any dictionary
with `String` keys; an item of a nested-row or flags element is a `[String: Any]`. `unpackMap` gives a
`String`, an `[Any]` for a list and a `[String: Any]` for a dict. Swift compares strings by canonical
equivalence, so two keys whose bytes differ but that are equal as Swift strings (an NFC and an NFD form)
cannot both sit in a `[String: Any]`: unpack refuses such a packet as "dict key given twice" (as
TypeScript refuses a key given twice), and pack refuses a Foundation dictionary that holds both. In a
typed row a list is bound to an array and a dict to a `[String: E]` of the element's Swift type (a
``PackbinRow`` for a nested-row or flags element, whose fields are bound to it; a `[UInt8]` holds a list
of u8); the element is never bound on its own. `nil` is no value; an empty array, dictionary or string
is a value with count 0 written. In a round a list, dict or byte run takes one value a round in an
array; a lone dictionary, byte run, or list inside a group map given once for every round is refused,
and a lone string goes to every round.

### Rounds and counted kinds

`.repeat(anchor, members...)` writes its members once a round until the buffer ends (nothing may
follow it); `.times(anchor, count: id, members...)` exactly as many times as the integer field `id`,
written earlier in the same scope. A round body is a scope of its own; a repeat or times cannot sit
inside a round, and a body with no member is refused. In a map row each name a round holds takes an
array, entry i for round i, `nil` where the round leaves the name out; a value that is not an array
goes to every round, and a `[UInt8]` is a byte run, never an array of rounds. A group in a round takes
one `[String: Any]` a round. `unpackMap` gives each name an `[Any?]` with one entry a round:

```swift
let route = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .i32(1, "lat"), .i32(2, "lon")), .u8(3, "tail"))
let raw = try pack(route, ["n": 2, "lat": [10, 30], "lon": [20, 40], "tail": 7])
// 01 02 0a 00 00 00 14 00 00 00 1e 00 00 00 28 00 00 00 07
```

In a typed row a round is bound to an array of a ``PackbinRow`` (or an optional of one), one element a
round, whose members the round's fields are bound to; a typed times refuses a count other than the
elements. `nil` writes no round, and unpack gives an empty array for 0 rounds read and `nil` for a
round that was not read.

`.sized(id, name, count:)` is raw bytes (`[UInt8]`) whose length is an earlier integer;
`.bits(id, name, count:)` a list of 0 and 1, one bit an item; `.packed(width, id, name, count:, bias:)`
a list of `width`-bit items (width 1 or 2, bias 0 or -1). Their values are arrays of integers (a
`[UInt8]` too) and unpack gives `[UInt8]`. `.u2(.slot(id, name), ...)` packs its slots two bits each,
four to a byte; a slot is 0...3, an integer count source and `eq` source, and unpack gives a `UInt8`.
A count is a wire integer up to u64: one that is absent, negative or above `Int.max` cannot be read
(`.short` with `needed` 0), and a count above 0 that the row gives behind a clear `when` is refused.

### Rows

A row is a `[String: Any]` keyed by field name, or a typed row: a type that conforms to
``PackbinRow`` (it has an `init()`) whose members are bound to fields with
``Field/bind(get:set:)``:

```swift
struct Position: PackbinRow {
    var sid: UInt16 = 0
    var heading: UInt16?   // nil: no value, the flag bit is clear
}

let sid = Field.u16(0, "sid").bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 })
```

`nil` (a missing key, a boxed `nil`, or a getter that returns `nil`) is no value; only a flag bit can
leave a value out (a list or dict written where a value is required is refused naming it). A stored 0 is a value and is written. Every value field and group of one row (the
top level, or a group's members) is bound to the same row type, or none is; a bound scheme packs that
type and `unpack` returns it, and `pack` and `unpackMap` still take and give the map form of any
scheme.

A member holds every value of its field: an integer type that holds the field's range (an `Int` for a
`u16`, not a `UInt8`), `Float` (f32 only) or `Double`, `[UInt8]` for fixed bytes, `Bool` for a bool,
`String` for utf8, an array or `[String: E]` for a list or dict, or an optional of one. Any other member type is refused when the scheme is built.

In a map row an integer field takes any Swift integer type whose value fits; a float field any
integer or float; fixed bytes a `[UInt8]` of exactly its size; a bool a `Bool`; utf8 a `String`. A Foundation
`NSNumber` (from `JSONSerialization`) is read as the `Bool`, integer or float it was made from. A `Bool`
or a `Double` (a whole `2.0` too) for an integer field, an integer for a bool, and any other type are
refused, naming the field id. `unpackMap` gives each value the Swift type of its field (`UInt8` to
`UInt64`, `Int8` to `Int64`, `Float`, `Double`, `[UInt8]`, `true`, `String`), so a row it returned
packs again to the same bytes.

### Pack and unpack

A refused row throws a ``PackbinError`` of kind ``PackbinError/Kind/packError`` naming the field id,
and no bytes are returned. A buffer that cannot be read throws ``PackbinError/Kind/short`` (the field,
the bytes needed and the bytes left), ``PackbinError/Kind/trailing`` or
``PackbinError/Kind/unknownType`` and gives no row. No input traps: every read is bounds-checked and
every size and value is converted with checked arithmetic.

### Concurrency

A built ``Scheme`` is immutable and `Sendable`: any number of tasks can pack and unpack with one
scheme at once. ``Field``, ``FlagByte``, ``Condition`` and ``PackbinError`` are `Sendable` too.

### Public names

The whole API is listed here.

- ``Scheme``: `init(_ typeNumber: Int, _ fields: Field...) throws`, `init(_:_: [Field]) throws`,
  `typeNumber`.
- ``Field`` constructors: `.u8`, `.u16`, `.u32`, `.u64`, `.i8`, `.i16`, `.i32`, `.i64`
  `(_ id: Int, _ name: String)`: integers, little-endian; `.f32`, `.f64(_ id:, _ name:)`: IEEE 754,
  little-endian, NaN and the infinities written as given, a finite value too large for f32 refused;
  `.bytes(_ id:, _ name:, size:)`: exactly `size` raw bytes, no length; `.be(_ field:)`: that integer
  or float, big-endian; `.bool(_ id:, _ name:)`: a flag bit with no payload, set only for `true`,
  only directly under `flags` or a flag byte's bit; `.flags(_ anchor: Int, _ members: Field...)`:
  one byte, bit i is member i, a clear bit skips the member, at most 8 members, the anchor is not
  written; `.flagByte(_ handle: FlagByte)`: where a split-form flag byte is read;
  `.when(_ anchor: Int, _ condition: Condition, _ members: Field...)`: the members only when an
  earlier field of the same scope equals the value, the anchor is not written;
  `.group(_ anchor: Int, _ name: String, _ members: Field...)`: the members under one name, and
  `.group(_ name: String, _ members: Field...)`: a nested row (see Groups). `flags`, `when` and `group`
  also take their members as an array.
- `.utf8(_ id: Int, _ name: String)`, `.list(_ name: String, _ element: Field)`,
  `.dict(_ name: String, _ element: Field)` (see Strings, lists and dicts).
- Round and counted constructors: `.repeat(_ anchor: Int, _ members: Field...)`,
  `.times(_ anchor: Int, count: Int, _ members: Field...)` (both also take an array),
  `.sized(_ id: Int, _ name: String, count: Int)`, `.bits(_ id: Int, _ name: String, count: Int)`,
  `.packed(_ width: Int, _ id: Int, _ name: String, count: Int, bias: Int = 0)`,
  `.u2(_ slots: Field...)` (or an array), `.slot(_ id: Int, _ name: String)` (see Rounds and counted
  kinds).
- ``Field/bind(get:set:)``: binds a value field, a list, a dict, a group, a repeat or a times to a
  member of a ``PackbinRow``.
- ``FlagByte``: `init(_ name: String)`, `name`, `bit(_ member: Field) -> Field` (the member under the
  next bit of the byte read before it in the same scope).
- ``Condition``: `.eq(_ id: Int, _ value: some BinaryInteger)`, `.eq(_ id: Int, _ value: Bool)`.
- ``PackbinRow``: a typed row; `init()`.
- `pack(_ scheme: Scheme, _ row: [String: Any]) throws -> [UInt8]`,
  `pack<Row>(_ scheme: Scheme, _ row: Row) throws -> [UInt8]`.
- `unpack(_ buffer: [UInt8], _ schemes: Scheme...) throws -> Any` (the bound row type, or a
  `[String: Any]`), `unpackMap(_ buffer: [UInt8], _ schemes: Scheme...) throws -> [String: Any]`;
  both also take the schemes as an array.
- ``PackbinError``: `kind`, `field` (`nil` for no field), `name`, `needed`, `left`, `actual`, `reason`;
  ``PackbinError/Kind``: `short`, `trailing`, `unknownType`, `badValue`, `tooMany`, `schemeError`,
  `packError`, whose raw values are the outcome terms of the shared hostile vectors.
- `flagBits`: the 8 bits one flag byte holds.
