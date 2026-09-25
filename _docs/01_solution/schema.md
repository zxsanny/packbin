# Schema

**Path:** `_docs/01_solution/schema.md`

A packet is a list. Field order is wire order. Names are for the value object and for errors. They are not written.

## Types

| Helper | Width | Notes |
|--------|-------|-------|
| `u8` `u16` `u32` `u64` | unsigned int | little-endian unless `be()` |
| `i8` `i16` `i32` `i64` | signed int | |
| `f32` `f64` | IEEE float | |
| `bytes(n)` | n raw bytes | fixed |
| `flags(name, fields)` | one `u8` plus those fields | bit 0 is the first field |
| `when(eq(field, value), fields)` | 0 or the group | tests a field already read |
| `repeat(fields)` | the group until the buffer ends | must end on a boundary |

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

Unpack appends one point per complete pair. A trailing partial pair is `ShortPacket` on `lat` or `lon`.

## What stays outside the schema

- Degrees × 10_000_000, kilometers per hour, dictionary strings. Those are application values stored in the integer the list names.
- Merging a missing field into the last object.
- Choosing a layout from the first byte. `unpack` takes handlers only. It reads byte 0 and runs the handler whose scheme type number matches. The type number is still written first.
