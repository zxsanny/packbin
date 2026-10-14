# Swift differences from TypeScript (running list for AZ-2520 and the README)

Collected from the worker reports (`_docs/03_implementation/batch_NN_loop26_report.md`). Each row is a documented difference, not a drift: AZ-2520 pins it with a test, the README lists the user-visible ones.

| Source | Row | Swift | TypeScript | Why |
|--------|-----|-------|------------|-----|
| AZ-2513 | `bytes(-1)` | refused at construction | builds | a negative size would trap; as Go |
| AZ-2513 | `2.0` for an integer; `1` for a bool bit | refused, naming the field | accepted | owner rulings Go-1 B, Go-2 A |
| AZ-2514 | group in a map row | nested `[String: Any]` both ways; a flat key naming a member of a group not given is refused | packs nested or flat, unpacks flat | owner ruling (Go-4 A); hex equal for the nested form |
| AZ-2514 | mark given `1` in a map | refused | bit left clear | extends Go-1 B to marks |
| AZ-2514 | short packet in a flags member in a group | reports the anchor field id | reports an empty name | as Go |
| AZ-2514 | `Condition.eq` float/string/null values | cannot be written (integers and `Bool` only); an integer wider than 64 bits is refused with TypeScript's text | accepts | typed API |
| AZ-2515 | typed rounds | bind `[E]`/`[E]?` of a `PackbinRow`, one element per round; a typed `times` count other than the element count is refused | no typed round | as Go and C# |
| AZ-2515 | u64 count 2^53 and up to `Int.max` | readable count (short with needed 2^53; `times` reads rounds) | needed 0 (number limit) | as Go and the others |
| AZ-2515 | `times` count 2^64-1 behind a clear `when` | refused naming the field | packs `0100025a00` | documented U6 exception; Swift follows the others |
| AZ-2515 | `[UInt8]` as the items of bits/packed | accepted (unpack gives `[UInt8]`, which must repack) | refuses a Uint8Array for bits | as Go |
| AZ-2515 | mark `1` in a round; group entry `true` in a round; flat member list beside an absent group | refused | bit clear (`010201`); `missing v`; — | Go-1 B, Go-4 A in rounds |
| AZ-2516 | nested-row member names | a nested row has a scope of its own: ten schemes TypeScript refuses ("declared inside a group and outside it") build; the anchored group still refuses a shared name | refuses | as Go and C# |
| AZ-2516 | `u2` or a flag byte as a list/dict element | refused | builds (`0102000102`, `01010000`) | loop 25 D2 A, as Go |
| AZ-2516 | a lone non-dictionary value for a dict name in a round | refused with the lone-dictionary text | refused, other text | text only |
| AZ-2516 | a list/dict inside a group map given once for every round | refused | sliced per round | Go-4 A |
| AZ-2516 | items of a nested-row or flags element in a map row | must be `[String: Any]`; a struct is refused | any object | typed API |
| AZ-2516 | dict keys equal under Unicode normalization (NFC/NFD) | unpack refuses ("dict key given twice"); pack refuses an `NSDictionary` holding both forms | keeps both | owner ruling 2026-10-14 |
| AZ-2516 | the nested row API | a `group` overload without an anchor (Go: `Nested`) | group without an anchor | naming |
| AZ-2516 | refusal of a whole list/dict | field `nil` (a list has no id) and the list's name; item errors name the element's id and name | — | as Go |
| AZ-2517 | refusing round name for the split-bits shape in unpack | the first name the round holds (`a`) | the split flag byte `m` | as Go; the hostile README says the label is not asserted |
| AZ-2517 | a limit value | any `Int` from 1; message "expected a positive integer, got N" | refuses 2^53 and fractions | no such values in Swift; as C#, Python, Go |
| AZ-2517 | unpack refusal over a limit | kind `.tooMany`, needed 0 | the interim short-packet shape with needed 0 | as Go; both allowed by the `limit` terms |
| AZ-2518 | unpack with an unusable scheme list (none, or a repeated type number) | spends a packet position, then refuses | Go: refuses without spending; TypeScript and C#: spend one | Swift follows TypeScript and C# |
| AZ-2518 | ChaCha20 block counter / packet position limits | refuses data needing a block after 2^32-1 and position 2^64-1 (unreachable for any real payload) | TypeScript wraps the block counter; Go refuses over 2^38 bytes and wraps its uint64 position | documented |
| AZ-2518 | session API shape | throws, with Go's error kinds (setup failures `.badValue` "session: ..."; pack before open `.packError`; unpack before open `.short`, needed 1, left 0) | returns null/false (TypeScript, C#); errors as values (Go) | language idiom |
| AZ-2518 | dependency on Apple platforms | SwiftPM resolves and clones swift-crypto and swift-asn1 on every platform; only linking is conditional (0 objects built on macOS) | — | README (AZ-2524) must say so |
| AZ-2519 | `pack_out_of_range_integer` refusal text | "300 does not fit in u8" | "a: 300 does not fit in u8" | text only; Go matches Swift |
| AZ-2519 | `pack_flags_short_list` refusal text | "nil where the member is absent" | "undefined" | language idiom; as Go |
| AZ-2519 | `invalid_utf8_dict_key` | the error has no field id ("at m"); name, needed 0 and left 4 match | field "m" | pinned as is |
| AZ-2519 | outcome term `bad_value` from unpack | Swift unpack never throws `.badValue`; an unusable value comes back as `.short` with needed 0 (negative count, invalid UTF-8, count behind a clear flag); the loader reads it as `bad_value` | same shape | as TypeScript and Go; the hostile README says so |
| AZ-2522 | ring row comparison | by Swift type and value (as Go's `reflect.DeepEqual`) | loose deepEqual | stricter |
| AZ-2522 | ring repack | the driver repacks only roundflags and roundwhen | — | as Go and TypeScript; bitwhen cannot repack by design |
| AZ-2520 | a Swift enum case given as a u8 value | refused ("expected an integer for u8, got ParityLevel"); its `rawValue` packs | a numeric enum is a number at runtime and packs | typed API |
| AZ-2520 | a flat key beside a given group or nested row (`{g:{a:1}, b:2}`) | not read: refused with "missing b", or ignored where the member is not needed (`{k:0,c:3,g:{mode:0}}` packs `0100010000`) | reads the flat key (packs `01010102`; refuses the second row with U11) | extends Go-4 A; Go behaves as Swift; **owner to confirm** (open decision O1) |
| AZ-2520 | U11 with a shared name in the outer row and the nested row not given (`{k:0,c:3}`) | packs `010000` | Go refuses with U11; TypeScript cannot build the scheme | **owner decides** whether Swift or Go aligns (open decision O2) |
| AZ-2520 | a string for a bool | refused | clears the bit | Go-1 B, same rule as the documented `1` |

