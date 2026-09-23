# Test Data Management

## Seed Data Sets

| Data Set | Description | Used by Tests | How Loaded | Cleanup |
|----------|-------------|---------------|-----------|---------|
| position | type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear | FT-P-01, FT-P-02, FT-P-03, NFT-PERF-01 | inline values from `results_report.md` | none; the call does not store the packet |
| flags | flags 0x00 and 0x20 around a uint16, and a stored 0 | FT-P-04, FT-P-05, FT-N-01 | inline | none |
| groups | conditional group and a repeated pair | FT-P-06, FT-P-07, FT-N-02 | inline | none |
| strings | `zxsanny`, empty, and 65536 bytes of `a` | FT-U-01, FT-U-02, FT-U-03, FT-U-04 | inline | none |
| lists | `[1, 2]`, one big-endian 1, list then a following byte, empty, 65536 elements | FT-L-01, FT-L-02, FT-L-03, FT-L-04 | inline | none |
| dictionaries | the 103-byte user value, empty triple, a repeated key | FT-D-01, FT-D-02, FT-D-03, FT-D-04, FT-D-05 | inline | none |
| handoffs | producer hex consumed by the next language | FT-H-01, FT-H-02, FT-H-03 | inline | none |

## Data Isolation Strategy

Each call gets its own input buffer. The packages do not keep the last packet.

## Input Data Mapping

| Input Data File | Source Location | Description | Covers Scenarios |
|-----------------|----------------|-------------|-----------------|
| results_report.md | `_docs/00_problem/input_data/expected_results/results_report.md` | Position hex, flag widths, group widths, speed bound, publish counts | FT-P-01 through FT-P-09, FT-N-01 through FT-N-04, NFT-PERF-01 |

## Expected Results Mapping

| Test Scenario ID | Input Data | Expected Result | Comparison Method | Tolerance | Expected Result Source |
|-----------------|------------|-----------------|-------------------|-----------|----------------------|
| FT-P-01 | position values | hex `4001000065cd1d00a3e1110100`, length 13 | exact | N/A | results_report.md position row 1 |
| FT-P-02 | that hex | five fields as named, motion field count 0 | exact | N/A | results_report.md position row 2 |
| FT-P-03 | position packed twice | byte mismatch count 0 | exact | N/A | results_report.md position row 3 |
| FT-P-04 | flags 0x00 and 0x20 | 0 extra bytes, then 2 extra bytes | exact | N/A | results_report.md flags rows 1–2 |
| FT-P-05 | optional value 0 | bit set, stored integer 0 | exact | N/A | results_report.md flags row 3 |
| FT-P-06 | conditional group | 0 extra bytes, or extra bytes equal to the group width | exact | N/A | results_report.md groups rows 1–2 |
| FT-P-07 | repeated group on a boundary | one value per complete group | exact | N/A | results_report.md groups row 3 |
| FT-N-01 | buffer ending inside the uint16 | error names field, needed, left; value count 0 | exact | N/A | results_report.md flags row 4 |
| FT-N-02 | 1 leftover byte, or 1 byte after the list | error; value count 0 | exact | N/A | results_report.md groups rows 4–5 |
| FT-P-08 | version tag, both languages, golden match | 2 packages, MIT, manual uploads 0 | exact | N/A | results_report.md publish row 2 |
| FT-P-09 | push or pull request | tests run; a failure fails the check | exact | N/A | results_report.md publish row 1 |
| FT-N-03 | version tag, golden mismatch > 0 | packages published 0 | exact | N/A | results_report.md publish row 3 |
| FT-N-04 | tag whose tree lacks a language | packages published 0 for that registry | exact | N/A | results_report.md publish row 4 |
| NFT-PERF-01 | position, 100000 round trips, one core | elapsed time | threshold_max | ≤ 1 second | results_report.md speed row 1 |
| FT-U-01 | string `zxsanny` | hex `07007a7873616e6e79`, text `zxsanny` | exact | N/A | AZ-1938 AC-1 |
| FT-U-02 | empty string | hex `0000`, text length 0 | exact | N/A | AZ-1938 AC-2 |
| FT-U-03 | 65536 bytes of `a` | bytes written 0 | exact | N/A | AZ-1938 AC-3 |
| FT-U-04 | count 7, 2 bytes left | needed 7, left 2, value count 0 | exact | N/A | AZ-1938 AC-4 |
| FT-L-01 | list `[1, 2]` little-endian | hex `020001000200`, list `[1, 2]` | exact | N/A | AZ-1939 AC-1 |
| FT-L-02 | list `[1]` big-endian | hex `01000001` | exact | N/A | AZ-1939 AC-2 |
| FT-L-03 | list `[1]` then byte 2 | hex `01000102`, list `[1]`, next field 2, bytes left 0 | exact | N/A | AZ-1939 AC-3 |
| FT-L-04 | empty list, and 65536 elements | empty hex `0000`; long list writes 0 bytes | exact | N/A | AZ-1939 AC-4 |
| FT-D-01 | user value | 103-byte hex, bytes left 0, six-language mismatch 0 | exact | N/A | AZ-1940 AC-1 |
| FT-D-02 | access keys inserted store, channel, map | mismatch against FT-D-01 is 0 | exact | N/A | AZ-1940 AC-2 |
| FT-D-03 | the 103-byte user hex | username, two roles, three access lists, wrong fields 0, bytes left 0 | exact | N/A | AZ-1940 AC-3 |
| FT-D-04 | empty string, list, and dictionary | hex `000000000000` | exact | N/A | AZ-1940 AC-4 |
| FT-D-05 | one dictionary key twice | value count 0 | exact | N/A | AZ-1940 AC-5 |
| FT-H-01 | six user-value handoffs | wrong fields 0, bytes left 0 | exact | N/A | AZ-1941 AC-1 |
| FT-H-02 | nested map and store | 58-byte hex, wrong fields 0, bytes left 0 | exact | N/A | AZ-1941 AC-2 |
| FT-H-03 | position record in each language | hex `4001000065cd1d00a3e1110100`, mismatch 0 | exact | N/A | AZ-1941 AC-3 |

## External Dependency Mocks

| External Service | Mock/Stub | How Provided | Behavior |
|-----------------|-----------|-------------|----------|
| npm registry | not called by the byte tests | the publish checks read the workflow result | a mismatch publishes 0 packages |
| NuGet registry | not called by the byte tests | same | same |

## Data Validation Rules

| Data Type | Validation | Invalid Examples | Expected System Behavior |
|-----------|-----------|-----------------|------------------------|
| integer field | value fits the width | a uint16 of 65536 | error, 0 bytes written |
| buffer | length matches the fields that are present | one byte short of a field | error, value count 0 |
