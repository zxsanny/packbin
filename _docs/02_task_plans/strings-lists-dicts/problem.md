---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Strings, lists, and dictionaries

packbin can declare a UTF-8 string, a list, and a dictionary on the same field list the six languages already walk. `pack` writes those fields. `unpack` reads them back. A C# object and a TypeScript object are the values passed in. They are not the schema.

The value this feature is for:

- `username` — one string (`zxsanny`)
- `roles` — a list of strings (`user`, `dispatcher`)
- `access` — a dictionary whose keys are strings and whose values are lists of strings (`store` → `read`, `write`; `channel` → `read`; `map` → `read`, `gps_fix`, `set`, `edit`)

The names `username`, `roles`, and `access` stay off the wire. A string contributes its length and its UTF-8 bytes. A list contributes its count and its elements. A dictionary contributes its count and its pairs. The keys inside `access` are data, so they are written.

Callers are the same as the rest of packbin: a .NET server, a TypeScript client, and the Python, Rust, Java, and C++ packages, when a packet holds text, a list, or a map.

Fixed-width packets that do not use these fields stay the size they are today. Reflecting a class or an interface with no field list is out of scope.
