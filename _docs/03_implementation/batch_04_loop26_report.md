# Batch 4 report — loop 26

Task: AZ-2516 (Swift strings, lists, dicts and nested rows, 5 points; stream A, `swift/**`). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2516 | Done | 7 of 7 ACs (AC-1 to AC-5 plus AC-3b); 187 tests in 36 suites (parent re-run: pass; strict release build 0 warnings); thread sanitizer 0 reports (worker); 35 of 35 mutation proofs red (one by a trap that proves the key-length bound is needed); 32 000 mutated packets over 8 collection schemes: same outcome in TypeScript and Swift (scratch harness). |

CI-parity: as batch 2.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 to 9, 12, 13 | differences from TypeScript (nested-row scope, `u2`/flag byte element, lone dict text, Go-4 A in lists, map-form items, NFC/NFD keys, nested row API name, list error fields) | added to `parity_differences.md` for AZ-2520 and the README | clear |
| 10 | a zero-width element packs but unpack refuses the same packet (copied from TypeScript) | AZ-2517 and AZ-2520 spec notes; the parent decides any change | unclear |
| 11 | U11 for a nested row under flags: Swift reads the pending count from the nested map's own written values; Go reads it from the row around | AZ-2520 probes Go | unclear |
