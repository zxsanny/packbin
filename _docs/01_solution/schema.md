# Schema

**Path:** `_docs/01_solution/schema.md`

A packet is a list. Field order is wire order. A gap, a repeated id, or an anchor that is not the next value id fails construction. The anchor is not written, repeat still has no count, and a list, a dict, and a nested group still start at 0. Names are for the value object and for errors. They are not written.

## Types

| Helper | Width | Notes |
|--------|-------|-------|
| `u8` `u16` `u32` `u64` | unsigned int | little-endian unless `be()` |
| `i8` `i16` `i32` `i64` | signed int | |
| `f32` `f64` | IEEE float | |
| `bytes(n)` | n raw bytes | fixed |
| `flags(anchor, name, fields)` | one `u8` plus those fields | bit 0 is the first field; the anchor is the next value id and is not written |
| `when(anchor, eq(field, value), fields)` | 0 or the group | tests a field already read in the same scope (see References); the anchor is not written |
| `repeat(anchor, fields)` | the group until the buffer ends | must end on a boundary; no count; the anchor is not written |
| `packed(width, id, count, bias)` | 1-bit or 2-bit list | item count is an earlier integer of the same scope plus a bias of 0 or −1; no length byte; low bits first |
| `times(anchor, count, fields)` | the inner fields N times | N is an earlier integer of the same scope; the anchor is not written; the next field is then read as itself |

`be(field)` switches that field to big-endian. The packet default stays little-endian.

Optional fields use `null` in C# and `undefined` in TypeScript. `0` is written.

## Short form

Position record. Flags bits, in order: heading `u16`, speed `u8`, altitude `i16`. All clear, so those three are absent and the packet is 13 bytes.

### TypeScript

Vue, React, and Node use this. No Vue plugin.

```ts
import { scheme, u8, u16, i16, i32, flags, BinaryPacker } from "packbin"

class Target {
  sid = 1
  lat = 500_000_000
  lon = 300_000_000
  profile = 1
  heading: number | null = null
  speed: number | null = null
  altitude: number | null = null
}

export const target = scheme<Target>(
  0x40,
  u16(0, (x) => x.sid),
  i32(1, (x) => x.lat),
  i32(2, (x) => x.lon),
  u8(3, (x) => x.profile),
  flags([
    u16(4, (x) => x.heading),
    u8(5, (x) => x.speed),
    i16(6, (x) => x.altitude),
  ]),
)

const bytes = BinaryPacker.pack(target, new Target())
// 40 01 00 00 65 cd 1d 00 a3 e1 11 01 00

let got: Target | undefined
const result = BinaryPacker.unpack(bytes, target.on((row) => {
  got = row
}))
if (!result.ok) {
  // result.field, result.needed, result.left
}
```

### C#

```csharp
using Packbin;

public sealed class Target
{
    public ushort Sid { get; set; } = 1;
    public int Lat { get; set; } = 500_000_000;
    public int Lon { get; set; } = 300_000_000;
    public byte Profile { get; set; } = 1;
    public ushort? Heading { get; set; }
    public byte? Speed { get; set; }
    public short? Altitude { get; set; }
}

public static readonly Scheme<Target> TargetScheme = new(0x40, f => [
    f.U16(0, x => x.Sid),
    f.I32(1, x => x.Lat),
    f.I32(2, x => x.Lon),
    f.U8(3, x => x.Profile),
    f.Flags(
        f.U16(4, x => x.Heading),
        f.U8(5, x => x.Speed),
        f.I16(6, x => x.Altitude))]);

var bytes = BinaryPacker.Pack(TargetScheme, new Target());
Target? got = null;
var err = BinaryPacker.Unpack(bytes, TargetScheme.On(row => got = row));
if (err is ShortPacket missing)
{
    // missing.Field, missing.Needed, missing.Left
}
```

Both snippets omit `heading`, `speed`, and `altitude`, so the flags byte is `0x00` and the buffer ends there.

Setting a bit is presence:

```ts
pack(target, { /* same fields */, heading: 90, speed: 10 })
```

```csharp
["heading"] = (ushort)90,
["speed"] = (byte)10,
```

Bit 0 and bit 1 are set. Altitude stays absent. Heading `0` would still set bit 0.

## Split form

Use this when the flags byte is not immediately in front of its fields. The live position record does this for an unknown profile: the flags byte is read, then an identity group, then the motion fields those flags control.

```ts
const motion = flagByte("motion")

const targetFull = packet([
  u8("type"),
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  motion,
  when(eq("profile", 0), [
    u8("shape"),
    flags("identity", [u16("name"), u16("group"), u16("label")]),
  ]),
  motion.bit(u16("heading")),
  motion.bit(u8("speed")),
  motion.bit(i16("altitude")),
  motion.bit(u8("frequency")),
])
```

```csharp
var motion = Field.FlagByte("motion");

Packet.Of(
    Field.U8("type"),
    Field.U16("sid"),
    Field.I32("lat"),
    Field.I32("lon"),
    Field.U8("profile"),
    motion,
    Field.When(Eq("profile", (byte)0),
        Field.U8("shape"),
        Field.Flags("identity", Field.U16("name"), Field.U16("group"), Field.U16("label"))),
    motion.Bit(Field.U16("heading")),
    motion.Bit(Field.U8("speed")),
    motion.Bit(Field.I16("altitude")),
    motion.Bit(Field.U8("frequency")));
```

`flags(...)` is the short form of a flag byte plus immediate `.bit` fields. Prefer it when the bytes really are adjacent.

A bit must come after its flag byte, in the same container. The top level, each `repeat` or `times` round, and each `list` or `dict` element is its own container, and so is a Java nested row (AZ-2233: a bit inside one needs a flag byte read inside it). A flag byte read inside a `when`, or outside the container that holds the bit, is not visible to that bit, and building the scheme fails naming the bit. A `when` body may use a flag byte read earlier in the container around it, as the example above does for `motion`. This check runs in TypeScript, C#, Java, Rust and Python (Python since loop 16, with its split form, AZ-2100); C++ applies it too, and also refuses a bit whose only flag byte sits inside a `when` that ended before it (AZ-2135).

A bit's number is its place among the bits of the flag byte read it follows: bit 0 is the first bit after the read, and one flag byte holds 8 bits per read. A flag byte can be read again later in the container, and its second read starts its own bits. Rust and C++ number this way, and so do TypeScript and Java since loop 16 (AZ-2135), where one flag byte handle can also be a member of any number of schemes. Python does too since loop 16 (AZ-2230), and C# is not changed yet.

## References

The field id inside `eq(...)` and the count id of `packed`, `sized`, `bits` and `times` name a value field that was read earlier in the same scope. The scopes are the ones above (the top level, each `repeat` or `times` round, each `list` or `dict` element), plus a nested row: an unanchored group in TypeScript, a nested-row group in C# and Java. `flags`, `when` and an ordinary group share the scope around them. A reference to a later field, to an id nobody declared, to a field inside a `repeat` or `times` body from outside it, or to an outer field from inside the body fails when the scheme is built, naming both ids (loop 13). A count names an integer field (which other kinds a package refuses differs; AZ-2126, AZ-2181). All six packages check the scope. Rust checks names as well as numeric ids (a name outside the scope, inside an earlier body or never declared is refused, loop 16, AZ-2117), and Python raises a `ValueError` at construction (loop 16, AZ-2113).

Unpack decides a `when` on the fields it has read. C# since loop 13, TypeScript since loop 16 (AZ-2197) and Rust since loop 16 (AZ-2237; map and typed form), like Java and Python, decide it on pack from the fields they wrote in the same scope, so a `when` that names a field an earlier `when` or a clear flag bit skipped does not match on either side and pack never returns bytes that unpack reads differently.

## Repeat

A trail whose count is "whatever is left":

```ts
packet([
  u8("type"),
  u16("sid"),
  repeat([i32("lat"), i32("lon")]),
])
```

```csharp
Packet.Of(
    Field.U8("type"),
    Field.U16("sid"),
    Field.Repeat(Field.I32("lat"), Field.I32("lon")));
```

Unpack gives each field one list entry per round, so `lat` and `lon` hold one entry per complete pair. A trailing partial pair is `ShortPacket` on `lat` or `lon`.

A round may hold optional fields (`when`, `flags`, a flag bit, a group). Then every name the round can hold gets one entry per round, `null` (`undefined` in TypeScript) for a round that skipped it, so the lists line up by round index and a repack gives the same bytes. Pack reads item i of each list for round i, and a `repeat` runs as many rounds as its longest list. C# and TypeScript do this since loop 13, as Java does, and Python since loop 16 (AZ-2134); Rust returns the rounds as groups, one per round (`"__repeat__"`, `"__times_<anchor>"` in the map form). A `repeat` or `times` cannot hold another `repeat` or `times` in C#, TypeScript and Python, which refuse it when the scheme is built; Rust refuses all but a `times` inside a `repeat`. Java and C++ allow it: Java gives each inner name one list per outer round (AZ-2127).

## Borrowed count

`packed` is a list of width 1 or 2. The item count is an earlier integer plus a bias of 0 or −1. Width 2 stores 0 … 3, four per byte. Values `0, 1, 2, 3` are the byte `e4`. Bias −1 with a count of 9 and eight 1-bits is `ff`. A count of 1 and bias −1 writes no bitset bytes. A list whose length is not that count fails and names the field.

`times` writes the inner fields exactly N times, then the next field. A count of 2, two lat/lon pairs, and a following `u8` of 7 unpacks with bytes left 0. The `7` is not another latitude.

Pack takes N from the count field, and the lists must hold N items. C# refuses a list with more or fewer, C++ refuses an array that does not match a non-zero count, and a Rust typed `times` refuses a `Vec` whose length is not N (a `PackError` naming the `times`). TypeScript, Python and Java refuse a list longer than N as well as a short one (loop 16, AZ-2185, AZ-2186, AZ-2187), and so does the map form of Rust when no rounds are given (AZ-2237).

One scheme uses both for a route: header, N two-bit kinds, N pairs, then N−1 straight-leg bits when that flag is set. The fixture hex is `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.

## What stays outside the schema

- Degrees × 10_000_000, kilometers per hour, dictionary strings. Those are application values stored in the integer the list names.
- Merging a missing field into the last object.
- Choosing a layout from the first byte. `unpack` takes handlers only. It reads byte 0 and runs the handler whose scheme type number matches. The type number is still written first.
