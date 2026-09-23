# packbin

Binary packing and unpacking across languages, declared as a field list, with zero overhead in the binary data.

You name the fields, their widths, and their order. `pack` writes those bytes. `unpack` reads them back. The schema stays in your source: no tag, no length prefix, no version, no schema id. A packet is exactly as long as the fields you listed.

C#, TypeScript, Python, Rust, Java, and C++ run the same list. Vue and React use the TypeScript package. Android uses the Java package.

## Example

A position record. Latitude and longitude are `i32` values (here, degrees × 10_000_000). That scale is yours. packbin stores the integer.

Motion is a flags byte. `heading`, `speed`, and `altitude` are left out, so those bits stay clear and those fields are not written. The buffer is 13 bytes: 1 + 2 + 4 + 4 + 1 + 1.

### Configuration in Python

```python
from packbin import flags, i16, i32, packet, u8, u16

target = packet([
    u8("type"),
    u16("sid"),
    i32("lat"),
    i32("lon"),
    u8("profile"),
    flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
])
```

Field order is wire order. Names are for your values and for errors. They are not written. Integers are little-endian unless you wrap a field in `be()`.

A counted string, list, or dictionary stores its own unsigned 16-bit count in front of its payload. That count is part of the field, not a prefix on the packet. Dictionary keys are UTF-8 strings written in unsigned byte order. A repeated key is an error and returns no values. 65536 elements do not fit.

### Pack

```python
from packbin import pack

raw = pack(target, {
    "type": 0x40,
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
})
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
```

### Configuration in TypeScript

```ts
import { flags, i16, i32, packet, u8, u16 } from "packbin"

const target = packet([
  u8("type"),
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
])
```

### Unpack

```ts
import { unpack } from "packbin"

const raw = new Uint8Array([
  0x40, 0x01, 0x00, 0x00, 0x65, 0xcd, 0x1d, 0x00,
  0xa3, 0xe1, 0x11, 0x01, 0x00,
])

const got = unpack(target, raw)
```

`got.ok` is `true`. The value is `type` `0x40`, `sid` `1`, `lat` `500000000`, `lon` `300000000`, `profile` `1`, `motion` `0`. `heading`, `speed`, and `altitude` are absent.

Set a field and its bit is set. `heading: 90` writes the `u16` and nothing else extra. `heading: 0` still sets the bit: zero is a value. Omit the key (`None` in Python, `null` or `undefined` in TypeScript) and the field is left out.

## Advantages

**Zero overhead in the binary data.** The wire holds the fields you declared. Thirteen bytes in, thirteen bytes out. A clear flags bit adds nothing for that field.

**One list, both directions.** You do not keep a separate offset walk, shift table, or `if` chain per language. The same helpers pack and unpack. If two languages disagree, the shared bytes disagree.

**A short buffer is an error.** When a present field does not fit, `unpack` returns no value. You get the field name, how many bytes it needed, and how many were left.

## Data types

| Helper | What it writes |
|--------|----------------|
| `u8` `u16` `u32` `u64` | unsigned integer, little-endian |
| `i8` `i16` `i32` `i64` | signed integer, little-endian |
| `f32` `f64` | IEEE 754 float |
| `bytes(n)` | exactly `n` raw bytes |
| `be(field)` | that number, big-endian |
| `flags(name, fields)` | one `u8`; bit 0 is the first field; a clear bit omits that field |
| `when(eq(field, value), fields)` | the group only when an earlier field equals `value`, otherwise nothing |
| `repeat(fields)` | the group until the buffer ends; it must end on a field boundary |

`flags` is the short form: the flags byte, then its fields immediately after. When other bytes sit between the flags byte and the fields it controls, declare the byte with `flagByte` (`flag_byte` in Python) and attach each field with `.bit`.

Full field rules: [`_docs/01_solution/schema.md`](_docs/01_solution/schema.md).

## License

MIT
