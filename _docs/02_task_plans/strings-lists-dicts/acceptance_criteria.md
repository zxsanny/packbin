# Feature acceptance criteria

Outcomes only. Project criteria in `_docs/00_problem/acceptance_criteria.md` stay in force. This file adds the string, list, and dictionary outcomes.

## Inherited

| Project AC | Why this feature exercises it |
|------------|--------------------------------|
| AC-1, AC-2, AC-3 | The position record stays 13 bytes, `4001000065cd1d00a3e1110100`, with 0 mismatched bytes across the six languages. |
| AC-8, AC-9 | A short field or trailing bytes still return an error and 0 values. |
| AC-10 | 100000 position round trips in each language still finish in ≤ 1 second. This feature adds no second speed target. |

## Text, lists, and dictionaries

- **F-AC-1.** Pack of `username` `zxsanny`, `roles` `user` then `dispatcher`, and `access` with `store` → `read`, `write`; `channel` → `read`; `map` → `read`, `gps_fix`, `set`, `edit` yields exactly 103 bytes: `07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465`. Mismatched bytes: 0. The six languages match. Mismatched bytes between them: 0.
- **F-AC-2.** Unpack of that hex yields `username` `zxsanny`, `roles` of length 2 (`user`, `dispatcher`), and `access` of 3 keys with those lists. Missing or wrong fields: 0.
- **F-AC-3.** Packing the same `access` map after inserting the keys as `store`, then `channel`, then `map` yields the F-AC-1 bytes. Mismatched bytes: 0.
- **F-AC-4.** An empty string, an empty list, and an empty dictionary, as the three fields of that same list, pack to exactly 6 bytes: `000000000000`.
- **F-AC-5.** A list of the two integers 1 and 2, each 2 bytes little-endian, packs to exactly 6 bytes: `020001000200`.
- **F-AC-6.** One big-endian 2-byte integer whose value is 1, as the only element of a list, packs to exactly 4 bytes: `01000001`.
- **F-AC-7.** Pack of a string whose UTF-8 form is 65536 bytes writes 0 bytes and fails. Pack of a list of 65536 elements writes 0 bytes and fails. Pack of a dictionary of 65536 pairs writes 0 bytes and fails.
- **F-AC-8.** Unpack of a string whose count says 7 bytes when 2 bytes remain returns an error and 0 values. The error names that field, needed 7, left 2.
- **F-AC-9.** Unpack of a dictionary that contains the same key twice returns an error and 0 values.
- **F-AC-10.** A list of one 1-byte integer `1`, followed by a 1-byte integer `2`, packs to exactly 4 bytes: `01000102`. Unpack yields the list `[1]` and the following field `2`. Missing fields: 0. The list does not consume the following field.

## Out of scope

- Using the C# class or the TypeScript type as the schema, with no field list
- An application table from an integer id to display text
- `repeat` as a list or dictionary element
- A code generator
- A speed target other than inherited AC-10
