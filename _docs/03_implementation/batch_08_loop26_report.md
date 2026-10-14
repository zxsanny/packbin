# Batch 8 report — loop 26

Task: AZ-2520 (Swift parity rows: TypeScript's U-row and AC-3 tables, 3 points; stream A, `swift/Tests`). Test files only; no Swift source changed. No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2520 | Done | 3 of 3 ACs; 331 tests in 54 suites (parent re-run: pass 31 s; strict release build 0 warnings); sanitizer 331 pass, 0 reports (worker); 22 of 22 mutation proofs red; TypeScript probed at HEAD before every row; Go probed in `golang:1.27` (a scratch copy of `go/`; the repo tree untouched); every `parity_differences.md` row has a Swift test except the two ring rows (pinned by the ring driver). The worker's TypeScript-row to Swift-test map is in its report (about 45 TypeScript test groups mapped; U9, U13, U18, U22 are C#/Rust only, U10 out of scope, U24 C++ only). |

CI-parity: as batch 2.

## Open owner decisions found here (for the loop 26 close handoff)

- **O1** A flat key beside a *given* group or nested row is not read in Swift (and Go): `{g:{a:1}, b:2}` is refused "missing b" where TypeScript reads the flat `b`; `{k:0,c:3,g:{mode:0}}` packs `0100010000` where TypeScript refuses with U11. Recommended: keep (extends the Go-4 A ruling; Go behaves the same); or refuse an unread flat key in both.
- **O2** U11 with a shared name in the outer row and the nested row not given (`{k:0,c:3}`): Swift packs `010000`, Go refuses with U11, TypeScript cannot build the scheme. Recommended: keep and document (the rare case needs a nested row whose member name repeats an outer name).

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | a Swift enum case is refused as a u8; its `rawValue` packs | `parity_differences.md` | clear |
| 2, 3 | O1 and O2 above | pinned as observed; owner | unclear |
| 4 | zero-width element: pack builds, unpack refuses, exactly as TypeScript in every variant | pinned | clear |
| 5 | a string for a bool is refused (Go-1 B) | `parity_differences.md` | clear |
