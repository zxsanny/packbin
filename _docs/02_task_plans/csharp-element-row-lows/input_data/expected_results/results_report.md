# Expected results — C# element row Lows (loop 111)

Hex measured on HEAD `05bdc52` (TypeScript run in loop 111 unless noted). Type number 1, little-endian `u16` count.

| case | input | expected output |
|------|-------|-----------------|
| when in element row | `(u8 mode, when(mode == 1, u8 speed))`, items `{mode 1, speed 7}`, `{mode 0}` | `01 0200 01 07 00`; unpack `{1, 7}`, `{0, 0}` (C# default for the skipped member) |
| times in element row | `(u8 c, times(1, c, u8 v))`, items `{c 2, v [5, 6]}`, `{c 0, v []}` | `01 0200 02 05 06 00`; unpack equal |
| array member, 0 / 1 / 3 rows | AZ-4199 `Comment` rows in a `Comment[]` | `010000` / `One` / `Three` of `csharp/tests/ElementRowTests.cs` (same as the `List<Comment>` form) |
| `IList<E>` member, 0 / 1 / 3 rows | same rows in an `IList<Comment>` | same hex as above |
| `IDictionary<string, E>` member | `{b: C2, a: C1}` | `Map` of `csharp/tests/ElementRowTests.cs` |
| member of another row type, element row | `Field.List<Marked, Mark>(x => x.Items, Field.U8<Other>(0, o => o.Id), Field.U8<Other>(1, o => o.Z))` | `ArgumentException` at scheme build naming `Z`, `Other` and `Mark` (today: `InvalidCastException` at `Pack`) |
| member of another row type, nested row | `Field.Group<Nest, Mark?>(x => x.M, Field.U8<Other>(0, o => o.Z))` | same refusal at build (today: `InvalidCastException` at `Pack`) |
| repeat in element row (out of scope, recorded) | `(u8 mode, repeat(1, u8 v))`, items `{1, [5]}`, `{2, []}` | today C# and TypeScript pack `01 0200 01 05 02` and refuse it on unpack; unchanged by this loop |
