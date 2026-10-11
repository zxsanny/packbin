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
