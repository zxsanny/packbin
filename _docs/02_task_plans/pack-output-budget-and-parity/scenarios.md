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

## Appended by feature-assess round 1 (loop 20, 2026-10-12)

Status `deferred (pending assessment)`; routing: the loop 21 handoff, no re-entry round. Details in `_docs/loops/loop20/assessment20.md`.

| # | Source | Scenario | Status |
|---|--------|----------|--------|
| 12 | assess-round-1 | Python unpack slot surcharge against pack (U1) | deferred (pending assessment) |
| 13 | assess-round-1 | slot width per package (U2) | deferred (pending assessment) |
| 14 | assess-round-1 | short list in an optional flags position (U3) | deferred (pending assessment) |
| 15 | assess-round-1 | Java split-bit count above 0, body absent (U4) | deferred (pending assessment) |
| 16 | assess-round-1 | C++ direct late `when` with another child setting the bit (U5) | deferred (pending assessment) |
| 17 | assess-round-1 | count 1 behind a clear `when`, no rounds: Python packs, C++ refuses (U6) | deferred (pending assessment) |
| 18 | assess-round-1 | `bits`/`packed`/`sized` counts behind a clear `when` in C#, Python, Java, Rust (U7) | deferred (pending assessment) |
| 19 | assess-round-1 | typed C# rounds bind only to object or collection members (U8) | deferred (pending assessment) |
| 20 | assess-round-1 | C# dict member in a round that cannot hold the rounds (U9) | deferred (pending assessment) |
| 21 | assess-round-1 | message and limit parity (U10) | deferred (pending assessment) |

