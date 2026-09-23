# Feature restrictions

Deltas on top of `_docs/00_problem/restrictions.md`. Anything not listed here stays as written there.

- A string, list, or dictionary field includes a 2-byte little-endian count. A packet that does not use those fields gains 0 bytes from this feature.
- The count is at most 65535. A string whose UTF-8 form is 65536 bytes or longer is rejected. A list or dictionary of 65536 elements or pairs is rejected.
- Dictionary pairs are ordered on the wire by the key's UTF-8 bytes, ascending, one byte at a time, unsigned.
- List and dictionary elements may be any existing field, including string, list, and dictionary. `repeat` is not an element.
- C#, TypeScript, Python, Rust, Java, and C++ all pack and unpack these fields in this feature.
