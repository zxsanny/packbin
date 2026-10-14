# Batch 7 report — loop 26

Tasks: AZ-2519 (Swift hostile vectors and the eighth package in the case checker, 3 points; stream A) and AZ-2522 (Swift in the language-pair ring, 3 points; stream B), in parallel with disjoint write sets. No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2519 | Done | 3 of 3 ACs; all 65 hostile cases (10 unpack, 2 limit, 15 construct, 38 pack) pinned with their full rule text, a wrong rule fails (3 self-tests); 299 tests in 48 suites (parent re-run: pass 31 s; strict release build 0 warnings); release 299 pass in 7.9 s, the 10 unpack cases total 0.001 s alone (worker); sanitizer 299 pass, 0 reports (worker); `check-cases.sh` "hostile cases ok: 65" and `cases.test.sh` pass (parent re-run); 24 of 24 mutation proofs red; same outcome as TypeScript on all 65 (two pack refusal texts differ). |
| AZ-2522 | Done except the 22 Go-Swift hand-offs | 3 of 3 ACs; `ring-wiring.test.sh` and `ring-wiring-swift.test.sh` pass (parent re-run); `run-suite.test.sh` pass; 136 Swift hand-off lines; a scratch ring with every Swift line except Go-Swift: 114 hand-offs and the 3 short refusals passed against C#, TypeScript, Python, Rust, Java and C++ in 20 s; session prints `b55d0a29c56c203712b241232e`, position prints the golden hex; 178 mutation proofs. The 22 Go-Swift hand-offs and the Docker fallback are proven by the first CI ring run (Go builds only in Docker on this Mac). |

CI-parity: as batch 2. Parent change: `scripts/loop-tests.sh` scaffold command also runs `ring-wiring-swift.test.sh`.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | Swift unpack never throws `.badValue` (short with needed 0 instead); the loader reads it as `bad_value`, as Go | `parity_differences.md`, hostile README | clear |
| 2 | pack texts differ from TypeScript in two cases; `invalid_utf8_dict_key` has no field id | `parity_differences.md` | clear |
| 3 | the hostile README has 38 pack sections + 2 limit sections with `Run by` (40 lines), not 41; construct-section descriptions that list packages do not name Swift | all 40 updated; the rest is a docs pass (AZ-2524 may add) | unclear |
| 4 | `ring-wiring.test.sh` runs in the scaffold job; the Swift guard runs as a ring-job step and in the loop script's scaffold stage | added to `loop-tests.sh` | resolved |
| 5 | `publish-position.sh` has no Swift yet | AZ-2523 spec note | clear |
| 6 | `language-pair.sh` is exactly 500 lines; the next language needs the table form or a split | loop 27 handoff | clear |
| 7 | CI assumes `ubuntu-latest` has Swift 6.x (major compared only); the fallback builds in `swift:6` with `--static-swift-stdlib`, not run; cold Linux ring build compiles BoringSSL (job timeout 30 min) | first CI ring run; handoff | unclear |
| 8 | the driver `Package.resolved` is a copy of the root's (a guard fails if they differ) | keep | clear |
