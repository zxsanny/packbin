# Expected Results

## Result Format Legend

| Result Type | When to Use | Example |
|-------------|-------------|---------|
| Exact value | Output must match precisely | hex, field count |

## Comparison Methods

| Method | Description | Tolerance Syntax |
|--------|-------------|-----------------|
| `exact` | Actual == Expected | N/A |

## Input → Expected Result Mapping

### User value

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|----------------|
| 1 | username `zxsanny`; roles `user`, `dispatcher`; access `store`→`read`,`write`, `channel`→`read`, `map`→`read`,`gps_fix`,`set`,`edit` | Pack, keys inserted in the order store, channel, map | 103 bytes, hex `07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465` | exact | N/A | N/A |
| 2 | the hex from row 1 | Unpack | username `zxsanny`; roles length 2; access length 3; wrong fields 0 | exact | N/A | N/A |
| 3 | empty string, empty list, empty dictionary | Pack of the same three fields | 6 bytes `000000000000` | exact | N/A | N/A |
| 4 | list of little-endian 2-byte integers 1, 2 | Pack | 6 bytes `020001000200` | exact | N/A | N/A |
| 5 | list of one big-endian 2-byte integer 1 | Pack | 4 bytes `01000001` | exact | N/A | N/A |
| 6 | string of 65536 UTF-8 bytes | Pack | 0 bytes written, pack fails | exact | N/A | N/A |
| 7 | string count 7 with 2 bytes left | Unpack | error, 0 values, needed 7, left 2 | exact | N/A | N/A |
| 8 | dictionary with one key written twice | Unpack | error, 0 values | exact | N/A | N/A |
| 9 | position type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion clear | Pack, regression | 13 bytes `4001000065cd1d00a3e1110100` | exact | N/A | `fixtures/golden.hex` |
| 10 | list of one 1-byte integer 1, then a 1-byte integer 2 | Pack and unpack | 4 bytes `01000102`; list `[1]`; following field `2` | exact | N/A | N/A |
