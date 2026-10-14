# Batch 10 report — loop 26

Task: AZ-2524 (README Swift section and the eight-language wording, 2 points; last task). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2524 | Done | 2 of 2 ACs; 335 tests in 55 suites (parent re-run: pass 31 s; strict release build 0 warnings); `check-cases.sh` "hostile cases ok: 65"; the README Swift code blocks are compared with the test's snippets by `readme_swiftBlocks_areTheSnippets` (2 mutations red: a code byte and the last session output byte); README places changed: Supported languages, `## Example` Swift section (install, typed and map snippets, "Swift rows"), Encrypted session, Data types lines, Untrusted input, Loop 26 note, Limits to keep in mind; `architecture.md` eight languages and ADR 005; `pack-session.md` Consumers line has Go and Swift. |

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | the README states an `NSNumber` is read as the Bool, integer or float it was made from: verified on macOS only | the first `swift:6` CI run proves Linux | unclear |
| 2 | the README says "CI runs the Swift suite in the `swift:6` image on Linux": that is the CI setup, not a passing Linux result; tvOS and watchOS are stated as not built or tested | reword after the first CI run if it fails | unclear |
| 3 | O1 and O2 (batch 8) are open owner decisions and are left out of the README | loop 26 close handoff | clear |
