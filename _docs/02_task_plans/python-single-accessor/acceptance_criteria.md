# Acceptance criteria

## Call shape

**AC-1: One member accessor packs the field.**
Given a position row with sid 1, lat 500000000, lon 300000000, profile 1, and the optional heading, speed, and altitude absent.
When each field is declared with one member accessor and the row is packed.
Then the hex is `4001000065cd1d00a3e1110100`. Wrong fields: 0.

**AC-2: Unpack writes that member.**
Given the hex `4001000065cd1d00a3e1110100` and one handler for that scheme.
When unpacked.
Then sid is 1, lat is 500000000, lon is 300000000, profile is 1. Bytes left: 0. Wrong fields: 0.

**AC-3: A mapping row uses the same call shape.**
Given a mapping whose sid is 1.
When the field accessor reads that key and the row is packed and unpacked.
Then sid is 1. Wrong fields: 0. Bytes left: 0.

**AC-4: A non-member accessor is rejected.**
Given an accessor that is not a plain member read.
When the field is declared.
Then declaration fails. Accepted non-member accessors: 0.

**AC-5: The README sample has no second function.**
Given the README Python example.
When counted.
Then occurrences of a `bind` helper are 0.

## Out of scope

- C#, TypeScript, Rust, Java, and C++ field signatures.
- The BinaryPacker rename.
- Writing a value back through a computed accessor.
