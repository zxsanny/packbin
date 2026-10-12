# Scenarios — loop 21

All rows `confirmed` (owner decisions of 2026-10-12 cover the proposed behavior); no `unknown` row.

| # | Axis | Scenario | Behavior | AC / spec |
|---|------|----------|----------|-----------|
| 1 | boundary | round packed at `maxSlots` / `maxSlots + 1`, empty group, duplicate leaves, `flags` | one rule in six; pack and unpack agree | AZ-2382, AZ-2381 |
| 2 | partial failure | short list in an optional flags position | refused | AZ-2383 |
| 3 | partial failure | split-bit `times`, count above 0, body absent / `[]` | packs a clear bit | AZ-2384 |
| 4 | partial failure | C++ late `when` in a bit body, another child sets the bit | packs (flash permitting) | AZ-2385 |
| 5 | partial failure | count 1 behind a clear `when`, no rounds | refused | AZ-2386 |
| 6 | partial failure | `bits`/`packed`/`sized` count behind a clear `when` | refused | AZ-2387 |
| 7 | invalid input | typed C# round on a row collection / a member that cannot hold rounds | binds / refused at build | AZ-2388, AZ-2389 |
| 8 | invalid input | C# `5.0` for an integer field | refused; unpack returns exact types | AZ-2373 |
| 9 | amplification | `times(65535) {}` over 65 535 list items | refused at build, under 1 s | AZ-2390 |
| 10 | performance | `times(65535) { u8 }` with 1 000 enclosing fields | within 2x of 100 fields | AZ-2391 |
| 11 | existing-feature overlap | accepted rows in golden/route/ring fixtures | bytes unchanged | AC-L12 |
| 12 | configuration | C# `WithLimits(maxRounds, maxSlots)` compiled before | still resolves | AZ-2393 |
