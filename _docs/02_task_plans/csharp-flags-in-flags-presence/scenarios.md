# Scenarios: a `flags` inside a `flags` (loop 118)

| # | actor / trigger / state | proposed behaviour | status | AC |
|---|-------------------------|--------------------|--------|----|
| 1 | scheme author packs `S` with both values (C#) | `01030109`, reads back | confirmed | F-1 |
| 2 | only the inner value | `01010109`, reads back | confirmed | F-2 |
| 3 | only the bool | `0102`, reads back | confirmed | F-2 |
| 4 | no value (boundary) | `0100`, reads back | confirmed | F-2 |
| 5 | C# dictionary form of the same scheme | same bytes as the typed form (no public dictionary reader) | confirmed | F-1 (pack only) |
| 6 | existing data: a packet C# wrote before the fix | was already lossy (the inner value was never written); it still reads as before; no upgrade note unless another package changes bytes | confirmed | constraint |
| 7 | another package differs from TypeScript | recorded in findings, one decision row; no fix in this loop | confirmed | F-4 |
| 8 | a `flags` nested two levels deep (`flags(flags(flags(u8 x)))`) | follows from the same arm (recursive); covered by one C# test | confirmed | F-1 |
