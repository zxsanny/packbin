# packbin — Problem

**Path:** `_docs/00_problem/problem.md`

## What

**packbin** is a small open-source library that packs and unpacks binary packets from a field list. One description per packet says the order, the widths, the endian, and which flags bit includes the next field. The same list is what C#, TypeScript, Python, Rust, C++, and Java execute.

The bytes on the wire are only the fields. packbin does not add a tag, a length prefix, a version byte, or a schema id.

## Who

Someone who already has a binary layout, or who must keep one, and who has more than one language speaking it.

This repository owns packing, unpacking, and the data schema shared by C#, Vue, and Android. It is in implementation.

The callers are a .NET server, a Vue client, and an Android app, plus a TypeScript client (React or Node), a Python tool, a Rust node, a C++ program, and a Java program. Android uses the Java package. Kotlin is not a separate package.

## Why it hurts

Hand-written pack and unpack walks each packet with offsets and `if`s. Every new field is edited on every language. A `uint16` on one side and an `int32` on the other still compiles. The map or the phone then applies a shifted coordinate.

Existing multi-language tools do not cover this shape:

- Protobuf, FlatBuffers, and MessagePack speak many languages and replace the bytes. A 13-byte position packet grows by a few tag bytes.
- Kaitai Struct can describe an existing layout and adds nothing, and it can pack only for Java and Python. C# and JavaScript can only unpack.
- One-language layout helpers (`@solana/buffer-layout`, BinarySerializer, and similar) still leave two lists that can drift, and a flags byte that drops the next field is awkward in all of them.

## What a caller does

1. Declare the packet as fields.
2. `pack` turns a value into the exact bytes.
3. `unpack` turns those bytes back into a value.
4. If the flags bit says a field follows and the buffer ends first, `unpack` reports a short packet and does not return a half value.
5. A shared golden packet fails when two languages disagree.

A clear flags bit is valid omission. The library leaves that field out of the result. Keeping the previous value is the application's merge, not a wire rule.

A flipped bit that still leaves a long enough buffer is not visible from field widths. A checksum detects that only when the schema declares one. This layout does not require a checksum.

## Worked size

A position record of type `64`, sid `1`, latitude `50°`, longitude `30°`, profile `1`, flags `0`:

`4001000065cd1d00a3e1110100`

Thirteen bytes. Latitude and longitude are `int32` degrees × 10_000_000. That scale belongs to the application. packbin stores the `int32`.

## Out of scope

- Inventing a new envelope, compression, or RPC
- A hosted service
- Dictionary tables, map state, or "keep the last value"
- Replacing Protobuf where a new protocol can accept its tags
- A wiki, or a separate Kotlin package, before the six packages agree on the golden bytes. Android uses the Java package.

## Name

packbin. A search at the time of this document found no current software using that name.
