# Expected results — pack session

| Id | Input | Output |
|----|--------|--------|
| ER-1 | Position row type 64, sid 1, lat 500000000, lon 300000000, profile 1, flags clear, packed clear | `4001000065cd1d00a3e1110100` |
| ER-2 | Same row, 32-byte seed, opener's 16 bytes, waiter unpacks | the same five fields, payload length 13 |
| ER-3 | Waiter packs that row on the same connection | opener sees the same five fields |
| ER-4 | Second row on that connection | field mismatches 0 |
| ER-5 | Same seed, a different 16-byte value, unpack A's payload | not the original five fields |
| ER-6 | Seed length 31 or 33, or join length 15 or 17 | 0 sessions |
| ER-7 | Pack before start or join | 0 payloads |
