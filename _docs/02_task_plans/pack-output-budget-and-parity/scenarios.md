# Scenarios — loop 20

All rows `confirmed` (owner decisions of 2026-10-11 cover the proposed behavior); no `unknown` row.

| # | Axis | Scenario | Behavior | AC / spec |
|---|------|----------|----------|-----------|
| 1 | boundary | packet of `maxBytes` / `maxBytes + 1` bytes | packs / refused naming member | AZ-2354 |
| 2 | amplification | lone `utf8` under a capped `times` | refused before the budget is passed | AZ-2354 |
| 3 | amplification | list element holding a `times` | refused at default; packs with a raised limit | AZ-2354 |
| 4 | boundary | rounds whose slots pass `maxSlots` | refused on pack as on unpack | AZ-2354 |
| 5 | boundary | `repeat` of `maxRounds` / `maxRounds + 1` entries | packs / refused | AZ-2355 |
| 6 | partial failure | split bit, count 0 after the byte, list / scalar | refused / packs | AZ-2356 |
| 7 | partial failure | combined `flags`, skipped count with values | refused | AZ-2360 |
| 8 | invalid input | `5.0` in C#, `BigDecimal` 1.5 in Java, u64 count in Java `sized` | refused | AZ-2358, AZ-2361 |
| 9 | hostile input | typed C# unpack of a set round | error result, no exception | AZ-2366 |
| 10 | existing-feature overlap | accepted rows in golden/route/ring fixtures | bytes unchanged | AC-L12 |
| 11 | configuration | limits API called without `maxBytes` | default 16 MiB; other limits as before | AZ-2354 |
