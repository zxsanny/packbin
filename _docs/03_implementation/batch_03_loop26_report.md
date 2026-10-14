# Batch 3 report — loop 26

Task: AZ-2515 (Swift rounds and counted kinds, 5 points; stream A, `swift/**`). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2515 | Done | 3 of 3 ACs; 139 tests in 28 suites (parent re-run: pass; strict release build 0 warnings); thread sanitizer 0 reports (worker); 33 of 33 mutation proofs red; the 15 TypeScript test files of AC-2/AC-3 pass at HEAD (295 tests); 3000 seeded packets per round shape give the same accepted set in TypeScript and Swift. |

CI-parity: as batch 2 (local `swift build -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` and `swift test`).

## Discovered during implementation

| # | Spec ref | Finding | Handling | clear/unclear |
|---|----------|---------|----------|---------------|
| 1 | AZ-2514 bug | a split bit holding a `flags` packed with the bit clear (`01 00` instead of `01 01 01 03`); fixed in `Scheme.swift` `flagMember`, mutation proof red | fixed in this task | clear |
| 2 to 8 | AC-2 | differences from TypeScript (typed rounds, u64 count, U6 times, `[UInt8]` items, Go-1 B/Go-4 A in rounds, message texts) | listed in `_docs/02_task_plans/swift-package/parity_differences.md` for AZ-2520 | clear |
| 9 | AZ-2517 | no pack caps yet; huge `times` over lone scalars loops until the caps exist | AZ-2517 spec note | clear |
| 10 | AZ-2516 | `Reader.reached` must be scoped per list/dict element | AZ-2516 spec note | clear |
