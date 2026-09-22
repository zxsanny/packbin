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
| Acceptance Criteria | 16 | 16 | 0 | 0 | every row Covered or WAIVED |
| Restrictions | 19 | 17 | 0 | 2 | every row Covered or WAIVED |
| **Total** | 35 | 33 | 0 | 2 | every row Covered or WAIVED |

## Uncovered Items Analysis

| Item | Status | Reason | Risk | Mitigation |
|------|--------|--------|------|-----------|
| R-11 | WAIVED | No calendar date was set | A release could slip with no alarm | The first publish is gated by the golden hex, not a date |
| R-12 | WAIVED | No budget number was set | None for a $0 library | Revisit if a paid service is added |

<!-- autodev-step5-post-architecture-pass: 2026-09-22 -->
