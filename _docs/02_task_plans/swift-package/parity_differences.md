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
