# Loop 101 expected results — TypeScript colliding dictionary keys

Read by running TypeScript (`node`, v22.23.0) on HEAD e02ddc2 of 2026-11-11 (probe: scratchpad `ts_before.ts`). Scheme `dict(d, u8(v))`, type byte `01`, keys given in this order.

| case | keys | TypeScript today | after this loop |
|------|------|------------------|-----------------|
| lone high and lone low | `\ud800`, `\udc00` | writes `0102000410efbfbd010410efbfbd02` (unpack refuses it: `needed` 0, `left` 0) | `RangeError`, `d: two keys are the same once an unpaired surrogate is written as U+FFFD` |
| U+FFFD and lone high | `�`, `\ud800` | writes the same packet | `RangeError` as above |
| three keys, two collide | `a`, `\ud800`, `\udc00` | writes `010300021061010410efbfbd020410efbfbd03` | `RangeError` as above |
| reversed pair and two lone halves | `\udc00\ud800`, `��` | writes `0102000710efbfbdefbfbd010710efbfbdefbfbd02` | `RangeError` as above |
| lone high and U+FFFF | `\ud800`, `￿` | `0102000410efbfbd010410efbfbf02` | unchanged |
| a and lone high | `a`, `\ud800` | `010200021061010410efbfbd02` | unchanged |
| one lone high | `\ud800` | `0101000410efbfbd01` | unchanged |

Dart already refuses the four colliding cases (kind `packError`, field null, name `d`, reason `d: two keys are the same once an unpaired surrogate is written as U+FFFD`) and writes the three others with the same bytes (`dart/test/collections/lone_surrogate_test.dart`).
