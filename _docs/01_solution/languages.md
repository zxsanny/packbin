# Supported languages

**Path:** `_docs/01_solution/languages.md`

This repository owns packing, unpacking, and the data schema shared by C#, Vue, and Android. It is in implementation. Vue uses the TypeScript package. Android uses the Java package.

The schema rules in [`schema.md`](schema.md) are the language contract. A language is in the first publish when its package packs and unpacks the same golden hex as the others.

## Order

| Order | Language | Package | Who imports it |
|-------|----------|---------|----------------|
| 1 | C# / .NET | NuGet `Packbin` | Server |
| 1 | TypeScript | npm `packbin` | Vue, React, Node |
| 1 | Python | PyPI `packbin` | Tools and scripts |
| 1 | Rust | crates.io `packbin` | A native node |
| 1 | Java | Maven Central `packbin` | Android and other Java programs |
| 1 | C++ | vcpkg `packbin` | A C++ program |

Vue and React are not separate languages. Kotlin is not in the first publish.

The first tag waits until all six match the golden hex. A language left out of that tree is not published.

## Same surface everywhere

Each package exports the helpers from [`schema.md`](schema.md): integer and float fields, `bytes(n)`, `be`, `flags` / `flagByte`, `when`, `repeat`, `pack`, and `unpack`.

Names follow the language. TypeScript stays camelCase (`flagByte`). C# stays PascalCase (`FlagByte`). Field names inside the list stay the same strings, so a short-packet error names the same field.

## Done for a language

- It packs the position fixture to `4001000065cd1d00a3e1110100`.
- It unpacks that hex to the same fields.
- A set flags bit adds only that field's width.
- A short buffer returns `ShortPacket` and no value.
- Its public registry page links the GitHub tree that published it.
