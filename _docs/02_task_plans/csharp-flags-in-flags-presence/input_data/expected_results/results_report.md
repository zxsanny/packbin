# Expected results: `flags(flags(u8 x), bool b)`, type 1

TypeScript is the reference (`typescript/src/flag-bits.ts` `bitOn`, case `flags`). Java gives the same bytes for the first row (queue item source, loop 113 review).

| combination | values | packet (hex) | read-back |
|-------------|--------|--------------|-----------|
| `both` | `x = 9`, `b = true` | `01 03 01 09` | `x = 9`, `b = true` |
| `x-only` | `x = 9` | `01 01 01 09` | `x = 9`, `b` false or absent |
| `b-only` | `b = true` | `01 02` | `x` absent, `b = true` |
| `none` | nothing | `01 00` | `x` absent, `b` false or absent |

C# before this loop: `both` packs `01 02` (the value of `x` is dropped, no error).
