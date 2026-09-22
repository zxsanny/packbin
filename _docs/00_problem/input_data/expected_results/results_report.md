# Expected Results

Maps each fixture to a quantifiable result. Latitude and longitude are `int32` degrees × 10_000_000. That scale belongs to the caller. packbin stores the integer.

## Result Format Legend

| Result Type | When to Use | Example |
|-------------|-------------|---------|
| Exact value | Output must match precisely | hex `4001000065cd1d00a3e1110100` |
| Threshold | Output must stay under a limit | 100000 round trips ≤ 1 second |

## Comparison Methods

| Method | Description | Tolerance Syntax |
|--------|-------------|-----------------|
| `exact` | Actual == Expected | N/A |
| `threshold_max` | actual ≤ threshold | `≤ <value>` |

## Input → Expected Result Mapping

### Position fixture

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|---------------|
| 1 | type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear | 13-byte position record | hex `4001000065cd1d00a3e1110100`, length 13 | exact | N/A | N/A |
| 2 | hex `4001000065cd1d00a3e1110100` | Unpack of row 1 | type 64, sid 1, lat 500000000, lon 300000000, profile 1; motion field count 0 | exact | N/A | N/A |
| 3 | row 1 packed by C# and by TypeScript | Same field list, two languages | byte mismatch count 0 | exact | N/A | N/A |

### Flags

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|---------------|
| 1 | flags 0x00, bit 5 is uint16 | Optional field clear | 0 extra bytes | exact | N/A | N/A |
| 2 | flags 0x20, bit 5 is uint16 | Optional field set | 2 extra bytes | exact | N/A | N/A |
| 3 | optional field value 0 | Zero is a real value | that field's bit is set and the stored integer is 0 | exact | N/A | N/A |
| 4 | buffer ends inside the uint16 selected by flags 0x20 | Short field | error names the field, needed byte count, remaining byte count; value count 0 | exact | N/A | N/A |

### Groups

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|---------------|
| 1 | conditional group, tested field not equal | Group omitted | 0 extra bytes | exact | N/A | N/A |
| 2 | conditional group, tested field equal | Group included | extra bytes equal the group width | exact | N/A | N/A |
| 3 | repeated group ending on a boundary | Whole groups only | one value per complete group | exact | N/A | N/A |
| 4 | repeated group with 1 leftover byte | Ends mid-group | error; value count 0 | exact | N/A | N/A |
| 5 | 1 or more bytes after a finished list | Trailing bytes | error; value count 0 | exact | N/A | N/A |

### Speed

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|---------------|
| 1 | AC-1 fixture, 100000 pack-then-unpack round trips, one core | Each first-release language | elapsed time | threshold_max | ≤ 1 second | N/A |

### Publish

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|---------------|
| 1 | push or pull request | GitHub `https://github.com/zxsanny/packbin` | tests run; a failing test fails the check | exact | N/A | N/A |
| 2 | version tag, golden mismatch count 0, all six languages in the tree | First publish | 6 packages from the same commit, MIT, manual uploads 0: npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and one C++ package | exact | N/A | N/A |
| 3 | version tag, golden mismatch count > 0 | Bytes disagree | packages published 0 | exact | N/A | N/A |
| 4 | version tag whose tree lacks a language | That registry | packages published 0 | exact | N/A | N/A |
