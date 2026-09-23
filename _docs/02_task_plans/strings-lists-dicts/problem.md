---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Strings, lists, and dictionaries

packbin can declare a UTF-8 string, a list, and a dictionary on the field list the six languages already walk. `pack` writes those fields. `unpack` reads them back. A C# object and a TypeScript object are the values passed in. They are not the schema.

The value this feature is for:

- `username` — one string (`zxsanny`)
- `roles` — a list of strings (`user`, `dispatcher`)
- `access` — a dictionary of string to list of string (`store` → `read`, `write`; `channel` → `read`; `map` → `read`, `gps_fix`, `set`, `edit`)

The names `username`, `roles`, and `access` stay off the wire. A string contributes a 2-byte little-endian byte count and then those UTF-8 bytes. A list contributes a 2-byte little-endian element count and then the elements. A dictionary contributes a 2-byte little-endian pair count and then the pairs. The keys inside `access` are data, so they are written. Pair order on the wire follows the key bytes, so two languages inserting the keys in different orders still produce one buffer.

Callers are the existing ones: a .NET server, a TypeScript client (Vue, React, or Node), and the Python, Rust, Java, and C++ packages.

A list or dictionary element may be any field the schema already has, including a string, a list, or a dictionary. `repeat` is not an element: it has no count of its own and it consumes the rest of the buffer.

Fixed-width packets that do not use these fields stay the size they are today. The position record is still 13 bytes.

Reflecting a class or an interface with no field list is out of scope. An application dictionary that maps an integer id to display text stays out of scope. That table is not this field.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Project restriction says packbin adds no length prefix. A string, list, or dictionary field includes a 2-byte count. | `_docs/00_problem/restrictions.md`; this feature's `restrictions.md` | resolved | Medium |
| Two equal dictionary keys in one buffer. Unpack returns an error and 0 values, the same as a short field. | This feature's acceptance criteria | resolved | Low |
