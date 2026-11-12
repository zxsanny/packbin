## 0.1.0

First release of the Dart package. It writes and reads the same bytes as the
C#, TypeScript, Python, Rust, C++, Java, Go and Swift packages.

- Schemes of typed rows (`rowScheme`, `bind`) and of `Map<String, Object?>`
  rows (`scheme`); every field helper of the other packages: integers, floats,
  fixed bytes, `utf8Field`, `list`, `dict`, `flags`, `flagBool`, `when`,
  `repeat`, `times`, `sized`, `u2`, `bits`, `packed` and groups.
- Unpack returns errors as values and never throws on input bytes; pack and
  scheme construction throw a `PackbinException` that names the field.
- A `repeat` must be the last thing a packet reads: it has no count, so
  unpack would read a field after it as another round. A scheme is refused
  when it is built if a field that can write a byte stands after the `repeat`,
  also after the `when`, `flags`, flag bit, group or nested row that holds it
  (`repeat <anchor>: <field> follows it; a repeat reads to the end of the
  packet, so nothing can follow it; use times`), or if the `repeat` sits
  inside a `list` or `dict` element or inside a round. Use `times` when
  something follows: it has a count.
- Limits (`maxRounds`, `maxSlots`, `maxBytes`) and the shared hostile vectors.
- Message error correction: parity by count or by percentage, unpack with
  repair.
- Frame mode: `FrameSession`, `MacKey`, `ReplayWindow`.
- Dart 3.13 and newer, native targets only (the Dart VM and ahead-of-time
  builds); no web. No dependency.
