# Expected Results — C++ on microcontrollers

Maps the inputs of this feature to the outputs the microcontroller build must produce. Byte vectors are not copied here: they are the vectors the host C++ suite already asserts, so the two can never drift.

## Result Format Legend

| Result Type | When to Use | Example |
|-------------|-------------|---------|
| Exact value | Output must match precisely | `mismatched_bytes: 0` |
| Threshold | Output must stay below a limit | `flash ≤ 8192 B` |

## Comparison Methods

| Method | Description | Tolerance Syntax |
|--------|-------------|-----------------|
| `exact` | Actual == Expected | N/A |
| `threshold_max` | actual ≤ threshold | `≤ <value>` |

## Input → Expected Result Mapping

| # | Input | Input Description | Expected Result | Comparison | Tolerance | Reference File |
|---|-------|-------------------|-----------------|------------|-----------|----------------|
| 1 | `fixtures/golden.hex` row | AC-1 project golden row, packed on QEMU `mps2-an385` | `4001000065cd1d00a3e1110100`, `mismatched_bytes: 0` | exact | N/A | `fixtures/golden.hex` |
| 2 | every `to_hex(...) == "…"` / hex literal asserted in `cpp/tests/*.cpp` | each row packed and each hex unpacked on QEMU | `mismatched_bytes: 0`, `mismatched_fields: 0`, `vectors_run == vectors_asserted` | exact | N/A | `cpp/tests/packbin_tests.cpp`, `scheme_tests.cpp`, `kinds_tests.cpp`, `field_id_binding_tests.cpp`, `borrowed_count_tests.cpp` |
| 3 | same vectors | big-endian host (QEMU user `s390x`/`ppc64`) | `mismatched_bytes: 0`, `mismatched_fields: 0` | exact | N/A | same |
| 4 | `pack-session` vectors | seed + nonce + packet index, on QEMU | padded bytes equal, `mismatched_bytes: 0` | exact | N/A | `cpp/tests/session_tests.cpp`, `_docs/02_task_plans/pack-session/` |
| 5 | AC-2 firmware | every field kind once | `malloc_calls: 0`, `cxa_throw_refs: 0` | exact | N/A | — |
| 6 | AC-2 firmware, reference target | size and stack reports | `flash ≤ 8192 B` (core + 14-field table), `stack ≤ 512 B`, `data_bss: 0 B` | threshold_max | `≤ 8192`, `≤ 512`, `= 0` | — |
| 7 | short / trailing / wrong type / full buffer / one group too many | AC-6 cases | `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany` with offset and field id | exact | N/A | — |
| 8 | host suite | `make test` + compile-fail + 100000 round trips | failures 0, round trips ≤ 1 s | exact, threshold_max | `≤ 1000 ms` | `cpp/tests/` |
