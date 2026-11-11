# Loop 103 expected results — C# and Java

Read by running each package on HEAD d4e6275 (loop 102 probes `Probe102`, re-run by the parent on 2026-11-11). Scheme: type 1, a dictionary `d` with `u8` values; keys in the order given.

| case | keys | C# today | Java today | after this loop (C#, Java) |
|------|------|----------|------------|----------------------------|
| A lone high and lone low | `\ud800`, `\udc00` | `0102000410efbfbd010410efbfbd02` (own unpack refuses: `ShortPacket(D, 0, 0)`) | `01020002103f0102103f02` (refused: `ShortPacket("", 0, 0)`) | refused, both |
| B U+FFFD and lone high | `�`, `\ud800` | same as A, unreadable | `01020002103f020410efbfbd01` (reads: `?` -> 2, U+FFFD -> 1: the lone half became `?`) | refused, both |
| C "?" and lone high | `?`, `\ud800` | `01020002103f010410efbfbd02` (reads) | `01020002103f0102103f02` (unreadable) | C# unchanged; Java `01020002103f010410efbfbd02` |
| D one lone high | `\ud800` | `0101000410efbfbd01` | `01010002103f01` | C# unchanged; Java `0101000410efbfbd01` |
| E text lone high | `s = \ud800` | `010410efbfbd` | `0102103f` | C# unchanged; Java `010410efbfbd` |

TypeScript (loop 101) and Dart (loop 100) already give: A, B refused; C `01020002103f010410efbfbd02`; D `0101000410efbfbd01`; E `010410efbfbd`.

Messages after: C# `<field name>: two keys are the same once an unpaired surrogate is written as U+FFFD` (`ArgumentException`), Java `dict: two keys are the same once an unpaired surrogate is written as U+FFFD` (`IllegalArgumentException`).
