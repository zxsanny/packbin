# packbin
Binary packing and unpacking across languages, declarative mapping, with zero overhead in the binary data.

## Position

Same type in Python and TypeScript.

`u8 type` · `u16 sid` · `i32 lat` · `i32 lon` · `u8 profile` · `flags motion`

### Python

```python
from packbin import flags, i16, i32, pack, packet, u8, u16

target = packet([
    u8("type"),
    u16("sid"),
    i32("lat"),
    i32("lon"),
    u8("profile"),
    flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
])

raw = pack(target, {
    "type": 0x40,
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
})
```

### TypeScript

```ts
import { flags, i16, i32, packet, u8, u16, unpack } from "packbin"

const target = packet([
  u8("type"),
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
])

const got = unpack(target, raw)
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
```

## User

Same type in C# and Rust. String, list, dictionary.

`utf8 username` · `list roles` · `dict access`

### C#

```csharp
using Packbin;

var user = Packet.Of(
    Field.Utf8("username"),
    Field.List("roles", Field.Utf8("role")),
    Field.Dict("access", Field.List("actions", Field.Utf8("action"))));

var raw = Pack.Run(user, new Dictionary<string, object?>
{
    ["username"] = "ada",
    ["roles"] = new List<object?> { "user", "admin" },
    ["access"] = new Dictionary<string, object?>
    {
        ["map"] = new List<object?> { "read", "edit" },
        ["store"] = new List<object?> { "write" },
    },
});
```

### Rust

```rust
use packbin::{dict, list, packet, unpack, utf8};

let user = packet(vec![
    utf8("username"),
    list("roles", utf8("role")),
    dict("access", list("actions", utf8("action"))),
]);

let got = unpack(&user, &raw).unwrap();
```

```
03 00 61 64 61 02 00 04 00 75 73 65 72 05 00 61 64 6d 69 6e
02 00 03 00 6d 61 70 02 00 04 00 72 65 61 64 04 00 65 64 69 74
05 00 73 74 6f 72 65 01 00 05 00 77 72 69 74 65
```

## Data types

| Helper | What it writes |
|--------|----------------|
| `u8` `u16` `u32` `u64` | unsigned integer, little-endian |
| `i8` `i16` `i32` `i64` | signed integer, little-endian |
| `f32` `f64` | IEEE 754 float |
| `bytes(n)` | exactly `n` raw bytes |
| `be(field)` | that number, big-endian |
| `utf8` | UTF-8 string, `u16` length |
| `list` | `u16` count, then that many elements |
| `dict` | `u16` pair count; keys in unsigned byte order |
| `flags(name, fields)` | one `u8`; bit 0 is the first field; a clear bit omits that field |
| `when(eq(field, value), fields)` | the group only when an earlier field equals `value` |
| `repeat(fields)` | the group until the buffer ends |

[`_docs/01_solution/schema.md`](_docs/01_solution/schema.md)

## License

MIT
