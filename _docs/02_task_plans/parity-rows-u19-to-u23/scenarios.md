# Loop 23 scenarios

Source: handoff23 owner rows and assessment22 gaps; all rows confirmed (owner "accept all recommended", 2026-10-13).

| # | Actor / trigger / state | Proposed behavior | Status | AC |
|---|------------------------|-------------------|--------|----|
| 1 | C++ scheme author builds `when(.., eq(-1, v), ..)` | `SchemeInvalid` at construction, names the `when` | confirmed | AZ-2431 AC-1 |
| 2 | C++ scheme with a non-negative `eq` id (existing data) | builds as at HEAD | confirmed | AZ-2431 AC-2 |
| 3 | C++ round body of only empty containers (boundary) | refused by the body rule at the round's id, independent of row 1 | confirmed | AZ-2431 AC-3 |
| 4 | C++ `packed` bias -1, count 1, no value, clear `when` | traced; README exception or `010000` as the five | confirmed | AZ-2432 AC-1/2 |
| 5 | Rust caller gives per-name lists beside `__repeat__` groups (invalid input) | refused with the name | confirmed | AZ-2433 AC-1 |
| 6 | Rust caller gives a nested `times` name list in a `repeat` with no groups | refused with the name | confirmed | AZ-2433 AC-2 |
| 7 | TypeScript row with a bigint count above 2^53 behind a clear `when` (boundary) | refused with the U11 message | confirmed | AZ-2434 AC-1 |
| 8 | Python / Rust caller raises `maxSlots` to 4 194 304 for the old worst packet (existing-feature overlap) | unpacks, same rows | confirmed | AZ-2435 AC-1 |
| 9 | C++ hostile loader / fixture README reader sees the `pack_novalue_count_clear_when_*` skip reasons | text gives the U20 trace (bound member refused `BadValue` at the member, unbound spelling exists) | deferred (pending assessment) | — (assess-round-1, G4) |
| 10 | Rust caller gives a value under a `flags` name in a `repeat` body with no `__repeat__` groups (invalid input) | refused naming the name (packs `01` today) | deferred (pending assessment) | — (assess-round-1, G5) |
| 11 | Rust caller gives a top-level `__times_N` for a `times` nested in a `repeat` body, with or without groups (invalid input) | refused naming the key, or as disagreeing beside groups (dropped today) | deferred (pending assessment) | — (assess-round-1, G6) |
| 12 | C++ scheme with an unbound `bits`/`packed`/`sized`, count 3 behind a clear `when` (boundary) | owner choice: refuse as the five, or README exception (packs `010000` today) | deferred (pending assessment) | — (assess-round-1, U24) |
| 13 | C++ scheme author gives a count id outside 0..32 767 or an own id above 32 767 (invalid config) | owner choice: refuse at construction, count ids only, or README note (wraps / fails at pack today) | deferred (pending assessment) | — (assess-round-1, U25) |
| 14 | C# caller packs a dictionary row for a scheme with a nested-row group sharing a name with the outer row | owner choice: read a nested dictionary, README line, or refuse the collision (inner takes the outer value today) | deferred (pending assessment) | — (assess-round-1, U26) |
