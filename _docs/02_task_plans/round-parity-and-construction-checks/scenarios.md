# Scenarios — loop 19

All rows `confirmed` (owner decisions of 2026-10-11 cover the proposed behavior); no `unknown` row.

| # | Axis | Scenario | Behavior | AC / spec |
|---|------|----------|----------|-----------|
| 1 | boundary | `times` count = maxRounds / maxRounds + 1 | packs / refused naming member | AZ-2329 |
| 2 | repeat | round after a round that skipped a value | fresh scope, no leak | AZ-2330 |
| 3 | partial failure | split flag byte, condition written after the byte | refused naming member | AZ-2331 |
| 4 | existing data | list of per-round buffers | packs as before | AZ-2332 |
| 5 | concurrent members | two sibling `flags` members | own scope each | AZ-2333 |
| 6 | boundary | count 0 with / without values | refused / zero rounds | AZ-2335 |
| 7 | invalid input | `eq(u8, 300)`, string, NaN, True | refused at construction | AZ-2338 |
| 8 | existing-feature overlap | accepted rows in golden/route/ring fixtures | bytes unchanged | AC-L13 |

## Appended by feature-assess round 1 (loop 19, 2026-10-11)

Status `deferred (pending assessment)`; routing: the loop 20 handoff, no re-entry round. Details in `_docs/loops/loop19/assessment19.md`.

| # | Source | Scenario | Status |
|---|--------|----------|--------|
| 9 | assess-round-1 | `repeat` with more entries than `maxRounds` on pack (U1) | deferred (pending assessment) |
| 10 | assess-round-1 | count 0 written after the byte with values (U2) | deferred (pending assessment) |
| 11 | assess-round-1 | absent `when` source in Rust (U3) | deferred (pending assessment) |
| 12 | assess-round-1 | C++ count behind a clear `when` (U4) | deferred (pending assessment) |
| 13 | assess-round-1 | whole floats for `eq` and slots (U5), enums (U6), C++ `eq(u8,true)` (U7) | deferred (pending assessment) |
