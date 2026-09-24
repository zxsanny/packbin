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
| Acceptance Criteria | 58 | 58 | 0 | 0 | every row Covered or WAIVED |
| Restrictions | 19 | 17 | 0 | 2 | every row Covered or WAIVED |
| **Total** | 77 | 75 | 0 | 2 | every row Covered or WAIVED |

## Uncovered Items Analysis

| Item | Status | Reason | Risk | Mitigation |
|------|--------|--------|------|-----------|
| R-11 | WAIVED | No calendar date was set | A release could slip with no alarm | The first publish is gated by the golden hex, not a date |
| R-12 | WAIVED | No budget number was set | None for a $0 library | Revisit if a paid service is added |

<!-- autodev-step5-post-architecture-pass: 2026-09-22 -->
