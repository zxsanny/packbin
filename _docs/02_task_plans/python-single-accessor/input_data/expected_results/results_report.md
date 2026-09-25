# Expected Results

## Result Format Legend

| Result Type | When to Use | Example |
|-------------|-------------|---------|
| Exact value | Output must match precisely | hex string |

## Comparison Methods

| Method | Description |
|--------|-------------|
| exact | Actual == Expected |

## Mappings

| Input | Expected | Method |
|-------|----------|--------|
| Position sid 1, lat 500000000, lon 300000000, profile 1, heading/speed/altitude absent, one accessor per field | hex `4001000065cd1d00a3e1110100` | exact |
| That hex unpacked | sid 1, lat 500000000, lon 300000000, profile 1, bytes left 0 | exact |
| Mapping sid 1 packed and unpacked through one key accessor | sid 1, wrong fields 0, bytes left 0 | exact |
| Accessor `row.sid + 1` at declaration | declaration fails, accepted count 0 | exact |
| README Python example | `bind` helper count 0 | exact |
