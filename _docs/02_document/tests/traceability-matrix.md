# Traceability Matrix

## Acceptance Criteria Coverage

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | FT-P-01, SM-01, NFT-RES-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | FT-P-02, SM-02 | Covered |
| AC-3 | All six languages' bytes match | FT-P-03 | Covered |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | FT-P-04 | Covered |
| AC-5 | A stored 0 is written | FT-P-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | FT-P-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | FT-P-07, FT-N-02 | Covered |
| AC-8 | Short field names field, needed, left, and returns 0 values | FT-N-01, NFT-RES-01, NFT-SEC-02 | Covered |
| AC-9 | Trailing bytes are an error and 0 values | FT-N-02 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | NFT-PERF-01, NFT-RES-LIM-01 | Covered |
| AC-11 | Tests run on every push and pull request | FT-P-09 | Covered |
| AC-12 | A matching tag publishes one package per language present | FT-P-08 | Covered |
| AC-13 | The first tag publishes exactly six packages | FT-P-08, FT-P-10 | Covered |
| AC-14 | A golden mismatch publishes 0 packages | FT-N-03 | Covered |
| AC-15 | A missing language publishes 0 packages | FT-N-04 | Covered |
| AC-16 | Published packages declare MIT | FT-P-08 | Covered |
| AZ-1938 AC-1 | `zxsanny` packs to `07007a7873616e6e79` | FT-U-01 | Covered |
| AZ-1938 AC-2 | An empty string is `0000` | FT-U-02 | Covered |
| AZ-1938 AC-3 | 65536 UTF-8 bytes writes 0 bytes | FT-U-03 | Covered |
| AZ-1938 AC-4 | A short string names needed 7 and left 2 | FT-U-04 | Covered |
| AZ-1939 AC-1 | A list of 1 and 2 is `020001000200` | FT-L-01 | Covered |
| AZ-1939 AC-2 | One big-endian 1 is `01000001` | FT-L-02 | Covered |
| AZ-1939 AC-3 | A list leaves the next field as `01000102` | FT-L-03 | Covered |
| AZ-1939 AC-4 | An empty list is `0000`; 65536 elements write 0 bytes | FT-L-04 | Covered |
| AZ-1940 AC-1 | The user value is the 103-byte hex | FT-D-01 | Covered |
| AZ-1940 AC-2 | Insert order does not change the hex | FT-D-02 | Covered |
| AZ-1940 AC-3 | Unpack returns the username, roles, and access lists | FT-D-03 | Covered |
| AZ-1940 AC-4 | Empty string, list, and dictionary are `000000000000` | FT-D-04 | Covered |
| AZ-1940 AC-5 | A repeated key returns 0 values | FT-D-05 | Covered |
| AZ-1941 AC-1 | Six handoffs unpack the user value | FT-H-01 | Covered |
| AZ-1941 AC-2 | Six handoffs unpack the 58-byte nested dictionary | FT-H-02 | Covered |
| AZ-1941 AC-3 | The position record stays 13 bytes | FT-H-03 | Covered |
| AZ-1945 AC-1 | Constant type byte is not a row value | FT-S-01 | Covered |
| AZ-1945 AC-2 | Unpack drops the constant | FT-S-02 | Covered |
| AZ-1945 AC-3 | Wrong type byte | FT-S-03 | Covered |
| AZ-1945 AC-4 | Absent type number keeps the golden position | FT-S-04 | Covered |
| AZ-1945 AC-5 | Illegal type placement fails at scheme build | FT-S-05 | Covered |
| AZ-1945 AC-6 | Six languages | FT-S-07 | Covered |
| AZ-1946 AC-1 | Pack takes the scheme | FT-S-01 | Covered |
| AZ-1946 AC-2 | Unpack takes the same scheme | FT-S-02 | Covered |
| AZ-1946 AC-3 | The scheme argument is required | FT-S-05 | Covered |
| AZ-1946 AC-4 | Wrong type byte | FT-S-03 | Covered |
| AZ-1946 AC-5 | Untyped path stays the golden position | FT-S-04 | Covered |
| AZ-1946 AC-6 | The row stays data | FT-S-05 | Covered |
| AZ-1946 AC-7 | Six languages | FT-S-07 | Covered |
| AZ-1949 AC-1 | Scheme replaces Packet | FT-S-06 | Covered |
| AZ-1949 AC-2 | The row has no type member | FT-S-04 | Covered |
| AZ-1949 AC-3 | Known scheme checks the leading byte | FT-S-03 | Covered |
| AZ-1949 AC-4 | Unknown buffer calls the matching handler | FT-S-06 | Covered |
| AZ-1949 AC-5 | Unknown type number | FT-S-06 | Covered |
| AZ-1949 AC-6 | Type numbers in one call are unique | FT-S-06 | Covered |
| AZ-1949 AC-7 | Six languages | FT-S-07 | Covered |
| AZ-1950 AC-1 | Member names are not the wire names | FT-B-01 | Covered |
| AZ-1950 AC-2 | Sibling references use the order | FT-B-02 | Covered |
| AZ-1950 AC-3 | Flags use child accessors | FT-B-03 | Covered |
| AZ-1950 AC-4 | Nested row type has its own ids | FT-B-04 | Covered |
| AZ-1950 AC-5 | Order must match the number | FT-B-05 | Covered |
| AZ-1950 AC-6 | Six languages | FT-S-07, FT-B-01 | Covered |
| 04_borrowed_count AC-1 | Width-2 list borrows the count | FT-C-01 | Covered |
| 04_borrowed_count AC-2 | Width-1 list uses count minus one | FT-C-02 | Covered |
| 04_borrowed_count AC-3 | The group stops, then the next field is read | FT-C-03 | Covered |
| 04_borrowed_count AC-4 | One route scheme round-trips | FT-C-04 | Covered |
| 04_borrowed_count AC-5 | Length and short tail fail closed | FT-C-05 | Covered |
| scheme-field-order AC-1 | Value fields are numbered in list order | FT-O-01 | Covered |
| scheme-field-order AC-2 | A continuing group shows the next value id | FT-O-02 | Covered |
| scheme-field-order AC-3 | A nested list starts at 0 | FT-O-03 | Covered |
| scheme-field-order AC-4 | Every Rust scheme build runs the check | FT-O-04 | Covered |
| scheme-field-order AC-5 | The failure rule is written next to the order sentence | FT-O-05 | Covered |
| scheme-field-order AC-6 | Existing packets keep their bytes | FT-O-06 | Covered |
| pack-session AC-1 | Clear pack is unchanged | FT-P-01 | Covered |
| pack-session AC-2 | One connection round-trips | FT-K-02 | Covered |
| pack-session AC-3 | The waiter can send | FT-K-03 | Covered |
| pack-session AC-4 | A second packet round-trips | FT-K-04 | Covered |
| pack-session AC-5 | Two clients do not share a stream | FT-K-05 | Covered |
| pack-session AC-6 | A bad setup creates nothing | FT-K-06 | Covered |
| pack-session AC-7 | Pack before the connection is open fails | FT-K-07 | Covered |
| pack-session AC-8 | The README shows both ways | FT-K-08 | Covered |
| AZ-2019 AC-1 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2019 AC-2 | The opener and the waiter round-trip | FT-K-02 | Covered |
| AZ-2019 AC-3 | The waiter sends | FT-K-03 | Covered |
| AZ-2019 AC-4 | A second packet round-trips | FT-K-04 | Covered |
| AZ-2019 AC-5 | Two sessions stay apart | FT-K-05 | Covered |
| AZ-2019 AC-6 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2019 AC-7 | Pack before open fails | FT-K-07 | Covered |
| AZ-2020 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2020 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2020 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2020 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2021 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2021 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2021 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2021 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2022 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2022 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2022 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2022 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2023 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2023 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2023 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2023 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2024 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2024 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2024 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2024 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2025 AC-1 | One ciphertext | FT-K-09 | Covered |
| AZ-2025 AC-2 | A peer unpacks it | FT-K-09 | Covered |
| cpp-microcontroller AC-1 | The core builds the embedded way | FT-E-01 | Covered |
| cpp-microcontroller AC-2 | No heap and no exceptions in a firmware image | FT-E-02 | Covered |
| cpp-microcontroller AC-3 | The same bytes on the target CPU | FT-E-03 | Covered |
| cpp-microcontroller AC-4 | The same bytes on a big-endian CPU | FT-E-04 | Covered |
| cpp-microcontroller AC-5 | Flash and stack budget | FT-E-05 | Covered |
| cpp-microcontroller AC-6 | Errors are values | FT-E-06 | Covered |
| cpp-microcontroller AC-7 | Scheme order is checked without throwing | FT-E-07 | Covered |
| cpp-microcontroller AC-8 | Strings and bytes are borrowed | FT-E-08 | Covered |
| cpp-microcontroller AC-9 | `f64` needs an 8-byte double | FT-E-09 | Covered |
| cpp-microcontroller AC-10 | The session runs on the board | FT-E-10 | Covered |
| cpp-microcontroller AC-11 | Host programs use the core API | FT-E-11 | Covered |
| cpp-microcontroller AC-12 | Installable from the embedded registries | FT-E-12 | Covered |
| cpp-microcontroller AC-13 | Every target runs in CI | FT-E-13 | Covered |
| AZ-2070 AC-1 | Every listed hostile case is present and well formed | FT-X-01 | Covered |
| AZ-2070 AC-2 | A malformed line fails the check | FT-X-01 | Covered |
| AZ-2070 AC-3 | Each case is described | FT-X-01 | Covered |
| AZ-2070 AC-4 | CI runs the check | FT-X-01 | Covered |
| AZ-2078 AC-1 | A reused flag-byte number round-trips | FT-X-02 | Covered |
| AZ-2078 AC-2 | Inner bits still read their own byte | FT-X-02 | Covered |
| AZ-2078 AC-3 | A zero-progress repeat ends | FT-X-03 | Covered |
| AZ-2078 AC-4 | Hostile vectors on the host | FT-X-04 | Covered |
| AZ-2078 AC-5 | Embedded profile and budgets hold | FT-E-05 | Covered |
| AZ-2081 AC-1 | A bool outside flags is refused | FT-X-05 | Covered |
| AZ-2081 AC-2 | An empty group outside flags is refused | FT-X-05 | Covered |
| AZ-2081 AC-3 | A bool inside flags is unchanged | FT-X-06 | Covered |
| AZ-2081 AC-4 | A u2 over 64 children is refused | FT-X-07 | Covered |
| AZ-2081 AC-5 | Embedded runner and budgets hold | FT-E-05 | Covered |
| AZ-2025 AC-3 | Clear pack still matches | FT-P-01 | Covered |
| AZ-2026 AC-1 | Both examples are in the README | FT-K-08 | Covered |
| AZ-2026 AC-2 | The session example matches the contract | FT-K-08 | Covered |

## Restrictions Coverage

| Restriction ID | Restriction | Test IDs | Coverage |
|---------------|-------------|----------|----------|
| R-01 | Library only. No server and no GPU | NFT-RES-LIM-01 | Covered |
| R-02 | Runs on the language runtime's host | FT-P-03 | Covered |
| R-03 | First publish is the six languages | FT-P-03, FT-P-08 | Covered |
| R-04 | Current .NET LTS and current Node LTS at first publish | FT-P-08 | Covered |
| R-05 | Kotlin is not in the first publish | FT-N-04 | Covered |
| R-06 | Vue and React use the TypeScript package | FT-P-08 | Covered |
| R-07 | No code generator in the first release | FT-P-08 | Covered |
| R-08 | No tag, length prefix, version byte, or schema id | FT-P-01 | Covered |
| R-09 | Public registry, not GitHub Packages | FT-P-08, FT-P-10 | Covered |
| R-10 | License is MIT | FT-P-08 | Covered |
| R-11 | No calendar deadline | — | WAIVED — the interview set no date, so there is no date to test |
| R-12 | No budget figure | — | WAIVED — no budget number was set |
| R-13 | Source is https://github.com/zxsanny/packbin | FT-P-09 | Covered |
| R-14 | CI runs on every push and pull request | FT-P-09 | Covered |
| R-15 | A version tag publishes each language in that commit | FT-P-08, FT-P-10 | Covered |
| R-16 | The first tag publishes the six packages together | FT-P-08 | Covered |
| R-17 | Later registries publish only when that language is in the tree | FT-N-04 | Covered |
| R-18 | A language absent from the tree is not published | FT-N-04 | Covered |
| R-19 | Registry credentials stay in the CI secret store | NFT-SEC-01 | Covered |

## Coverage Summary

| Category | Total Items | Covered | BLOCKED | WAIVED | Coverage |
|----------|-----------|---------|---------|--------|----------|
| Acceptance Criteria | 136 | 136 | 0 | 0 | every row Covered or WAIVED |
| Restrictions | 19 | 17 | 0 | 2 | every row Covered or WAIVED |
| **Total** | 155 | 153 | 0 | 2 | every row Covered or WAIVED |

## Uncovered Items Analysis

| Item | Status | Reason | Risk | Mitigation |
|------|--------|--------|------|-----------|
| R-11 | WAIVED | No calendar date was set | A release could slip with no alarm | The first publish is gated by the golden hex, not a date |
| R-12 | WAIVED | No budget number was set | None for a $0 library | Revisit if a paid service is added |

<!-- autodev-step5-post-architecture-pass: 2026-09-22 -->
