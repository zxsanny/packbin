---
loop: 6
branch: loop/6-python-single-accessor
---

# Python single accessor

A Python scheme field takes one member accessor. Pack reads that member. Unpack writes it back. The caller does not pass a separate setter.

Callers are people writing a Python `Scheme` next to the other five languages. Today `u16(0, *bind("sid"))` takes a getter and a setter. The other languages take one member read, such as `(x) => x.sid`.

In scope: every Python field helper that currently takes `get` and `set` accepts one accessor of the form `lambda row: row.sid` or `lambda row: row["sid"]`. Object rows and mapping rows both round-trip. The README Python example contains no `bind` helper. An accessor that is not a plain member read is rejected. The position packet stays `4001000065cd1d00a3e1110100`.

Out of scope: C#, TypeScript, Rust, Java, and C++ signatures. The `BinaryPacker` rename in `binary_packer.md`. Computed accessors such as `lambda row: row.sid + 1`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A computed accessor has nowhere to write the unpacked value. | This feature's acceptance criteria | resolved | Low |
| Loop 5 is already stamped on `binary_packer.md`, so this loop is 6. | Hopper claim | resolved | Low |
