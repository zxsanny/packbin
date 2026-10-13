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
