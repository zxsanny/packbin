# Expected results — loop 54

## C# repeated text

| Input | Expected output |
|-------|-----------------|
| `u8 n; times(n){ utf8 s }`, n = 200, s = 65,535 × `q`, packed then unpacked | 13,107,802 bytes (as measured on CI and locally), unpacks to 200 equal strings; at most 250 ms idle, at most 1 s × load factor in the test |
| the same scheme, rounds 0 to 99 = text A, rounds 100 to 199 = text B (same length, last character differs) | packet equals A's field 100 times then B's field 100 times, each produced by the uncached encoder |
| alternating A, B, A, B … | each round's field equals the uncached encoding of that round's text |
| one text of 65,536 UTF-8 bytes | refused, message unchanged from today |

## C++ `when` of a skipped source

Scheme S (ids as in the packages' builders): `u8 mode; when(mode==1){ u16 a; u8 k }; when(k==2){ u8 b }`. Scheme S0 is the same with `when(k==0)`. Packet bytes are the Python package's, with scheme id 1 (the C++ probe prints `21` as its first byte; compare the bytes after the id).

| Scheme | Row | Packed (after the scheme id) | Unpacked |
|--------|-----|------------------------------|----------|
| S | mode 0, a 7, k 2, b 5 | `00` | `{mode: 0}` |
| S | mode 1, a 7, k 2, b 5 | `01 07 00 02 05` | `{mode: 1, a: 7, k: 2, b: 5}` |
| S0 | mode 0, a 7, k 0, b 5 | `00` | `{mode: 0}` |
| S0 | mode 1, a 7, k 0, b 5 | `01 07 00 00 05` | `{mode: 1, a: 7, k: 0, b: 5}` |

Source of the bytes: Python package on 2026-10-21 (`PYTHONPATH=python/src python3.14`); the Rust std and new core agree on the first row per the loop 51 note. The C++ result today for the first row is `00 05` after the id, which `unpack` refuses with `TrailingBytes`.
