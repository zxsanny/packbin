# packbin — Solution

**Path:** `_docs/01_solution/solution.md`

## Product

This repository owns packing, unpacking, and the data schema shared by C#, Vue, and Android. It is in implementation.

Six packages each export a field vocabulary and two functions, `pack` and `unpack`. The shared schema for those three callers is specified here. The packages do not contain any other product's packets.

```
application field list
        │
        ├─ NuGet, npm, PyPI, crates.io, Maven Central, and vcpkg
        └─ the same bytes
```

Vue and React import the npm package. They do not get a separate package or a plugin.

There is no code generator in the first release. Each of the six languages writes the list in that language. Golden packets are the check that the lists still match. A compiler from one schema file is a later option if those lists drift.

## What was rejected

| Candidate | Why it is not packbin |
|-----------|------------------------|
| Protobuf, FlatBuffers, MessagePack | They add their own bytes |
| Kaitai Struct | Read is multi-language; write is Java and Python only |
| Per-language layout libraries | Two lists, and flags-omission is custom code of the same size as packbin |
| A YAML compiler on day one | The walker is the product; a compiler can wait until a third language is typing the same list by hand |

## Walker rules

- Default endian is little-endian. A field can be marked big-endian.
- `flags` uses bit 0 for the first listed field. A set bit writes the field. A clear bit skips it. Zero is a real value, so absence is `null` / `undefined`, not `0`.
- The short form places those fields immediately after the flags byte.
- The split form stores the flags byte now and places each bit's field later. That covers a packet whose optional bytes are not adjacent to the flags byte.
- `when` inserts a group only when an earlier field equals a value.
- `repeat` reads a group until the buffer is used up. The buffer must end on a group boundary. One leftover byte is a short packet.
- `unpack` consumes the whole buffer. Leftover bytes are an error for one message that is one packet.
- `unpack` on a short field returns an error that names the field, how many bytes it needed, and how many remained. It does not return a partial object.
- `pack` writes only the fields the value includes. It does not pad.

## Errors

| Case | Result |
|------|--------|
| Flags bit clear | Field omitted from the value |
| Flags bit set, buffer ends | Short packet, named field |
| `repeat` ends mid-group | Short packet, named field |
| Bytes left after the list | Trailing bytes |
| Value present for a clear conceptual absence | Caller passes `null` / `undefined` to keep the bit clear |

## Testing

Each language runs the same hex fixtures.

- Position-only record above packs to `4001000065cd1d00a3e1110100` and unpacks to the same fields.
- Flags `0x20` on a list whose bit 5 is a `uint16` adds two bytes. Flags `0x00` omits them.
- A buffer that ends inside that `uint16` is a short-packet error and yields no value.
- C# bytes and TypeScript bytes for each fixture are identical.

## Related

- Schema surface: [`schema.md`](schema.md)
- Language order: [`languages.md`](languages.md)
- Registries: [`../04_deploy/packages.md`](../04_deploy/packages.md)
