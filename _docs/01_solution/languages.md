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
| 2 | C++ (microcontrollers) | PlatformIO `zxsanny/packbin`, Arduino Library Manager `packbin`, ESP-IDF component `zxsanny/packbin` | Firmware on 32-bit microcontrollers. CI builds Cortex-M0+, M3 and M4F, ESP32-S3, ESP32-C3 and RP2040; nRF52, STM32 and Cortex-M33 are expected to work with the same core but are not built in CI |

Vue and React are not separate languages. Kotlin is not in the first publish.

The C++ package is one allocation-free, exception-free core (C++17, no heap, no RTTI) for host programs and firmware alike; its pack and unpack write into and read from caller buffers and return a `Result`, and CI also checks the same bytes on a big-endian CPU (s390x on QEMU user mode); the embedded registries publish the same sources from the same tag. The Arduino layout is a generated `arduino` branch with an `arduino-<version>` tag, like the vcpkg port. 8-bit AVR is a stretch target, not a supported one.

The first tag waits until all six match the golden hex. A language left out of that tree is not published.

## Same surface everywhere

Each package exports the helpers from [`schema.md`](schema.md): integer and float fields, `bytes(n)`, `be`, `flags` / `flagByte`, `when`, `repeat`, `pack`, and `unpack`.

Names follow the language. TypeScript stays camelCase (`flagByte`). C# stays PascalCase (`FlagByte`). Field names inside the list stay the same strings, so a short-packet error names the same field. C++ is the exception: a field has an order id and a bound struct member, and the error carries the order id and the byte offset.

## Done for a language

- It packs the position fixture to `4001000065cd1d00a3e1110100`.
- It unpacks that hex to the same fields.
- A set flags bit adds only that field's width.
- A short buffer returns `ShortPacket` and no value. In C++ the result is `Error::ShortPacket` with the order id, the byte offset and the bytes needed, and the row keeps the fields read before the failure.
- Its public registry page links the GitHub tree that published it.
