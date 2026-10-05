# Split-form flag bits by field order per read (TypeScript, C#, Java) and C++ `when` scope

**Task**: AZ-2135_split_bits_field_order
**Name**: Split bits by field order
**Description**: TypeScript, C# and Java number split-form bits by field order for each flag-byte read, as Rust and C++ do; C++ stops binding a bit to a flag byte read inside an earlier `when`.
**Complexity**: 5 points (split per package when refined)
**Dependencies**: AZ-2079, AZ-2080, AZ-2089
**Component**: typescript, csharp, java, cpp
**Tracker**: AZ-2135
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` G4, G1), deferred from loop 12 by the owner.

- **G4**: TS, C# and Java still number split bits by `.bit()` call order on a shared handle:

| Probe | TS | C# / Java | Rust (loop 12) |
|-------|----|-----------|----------------|
| one handle, two schemes `[m, m.bit(u8 x)]`, x=5 | `010105` / `010205` | `010305` / `010305` | `010105` / `010105` |
| `[m, early a, late b]` (late created first), b=9 | `010109` | `010109` | `010209` |
| `[m, m.bit(a), m, m.bit(b)]`, b=9 | `01020209` | `01020209` | `01000109` |

  C# and Java also count a ninth bit across every scheme that shares a handle. Basis: C05 "bit positions from field order"; AZ-2082 Outcome; AZ-2100 Included; `README.md` upgrade note.
- **G1**: C++ `find_flag_byte` (`cpp/include/packbin/order.hpp:111-124`) looks inside a `when`: `u8 k, flag_byte(0), when(k==1, [flag_byte(0), flag_bit(0, u8 a)]), flag_bit(0, u8 b)` with `{k:0, b:6}` packs `01000006` (own unpack `TrailingBytes`); a byte only inside the `when` still builds. `schema.md:167` and the loop 11 U2 decision make both a construction error.

## Acceptance Criteria

**AC-1**: the three G4 probes give the Rust bytes in TS, C# and Java; a handle shared by two 5-bit schemes builds both.
**AC-2**: C++ packs `01000106` / `010101010506` for `{k:0, b:6}` / `{k:1, a:5, b:6}` and both unpack; with no outer `flag_byte(0)` building fails with `SchemeInvalid` naming `b`.
**AC-3**: golden, route and motion examples unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire change for handle-reuse and re-read shapes in TS, C#, Java; split into one task per package when the loop takes it | coordinator | open | Medium |
