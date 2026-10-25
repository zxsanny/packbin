# Batch 01 — loop 71 (frame mode in C#, Java, Swift)

Commit `d99414e`. Tasks: AZ-3232 (C#), AZ-3233 (Java), AZ-3234 (Swift), AZ-3235 (docs, parent). Three workers on disjoint trees (`csharp/`, `java/`, `swift/`), each ran only its package suite (owner rule 2026-10-06: one total test run at step 11; no per-batch review).

## Results (as the workers ran them, stdin from /dev/null)

| package | run | result |
|---|---|---|
| C# | `dotnet test csharp` (net10.0, and `-p:PackbinTarget=netstandard2.0`) | 4305 passed, 0 failed, both runs (66 new tests) |
| Java | `bash java/test.sh` | exit 0; `api-check PASS` (Android API 26); 7 new test classes pass |
| Swift | `swift test`; strict release build `-warnings-as-errors -strict-concurrency=complete`; `--sanitize=thread` | 461 tests passed; build complete, 0 warnings; 30 sanitizer tests passed |
| README | `bash scripts/frame/readme-examples.sh` | PASS for C#, Java, Swift |

`CI-parity`: the package compile and test commands above are the ones `run-suite.sh` runs; Linux swift-crypto and the Docker stages run at step 11.

## Discovered during implementation

| # | scenario or question | spec ref | proposed handling | clear |
|---|---|---|---|---|
| 1 | C# and Java had no `BadValue` / `BufferFull` error values | AZ-3232, AZ-3233 AC-8 | added both beside the three new kinds (5 classes) | clear |
| 2 | Swift had no buffer-full kind | AZ-3234 AC-8, AC-12 | added a 4th kind `bufferFull` "buffer_full"; the pinned list holds the 9 old values + 4 | clear |
| 3 | The platform HMAC cannot hold precomputed pad states | contract (72-byte figure) | sessions hold the 32-byte MAC key per direction, `MacKey` the label key; wiped on release; stated in docs | clear |
| 4 | `SetPrevious`, `ClearPrevious`, close/dispose are not safe beside a concurrent `Open` | S9 | documented; seal is thread safe | clear |
| 5 | `Load`/`Derive` return null (C#, Java), throw `badValue` (Swift) | AC-1 | follows each package's `PackSession.Load` | clear |
| 6 | Swift: a `msgID` that is not 8 bytes, or a negative `clearLength`, throws `badValue` (Rust gets these from its types) | AC-8 | kept, `BadValue` before `TooLong` | clear |
| 7 | Linux `swift-crypto` could not be run in the worker | AC-12 (Swift) | verified by the step 11 swift stage in Docker | unclear until step 11 |
| 8 | AC-9 "reads every byte" is a source-text check plus behaviour tests, brittle if the helper is reformatted | AC-9 | accepted | clear |
| 9 | `fixtures/crypto/vectors.txt` has 27 data rows, `fixtures/frame/vectors.txt` 157 (the specs said 39 and 170: line counts) | AC-1, AC-2 | specs corrected | clear |
| 10 | Java `SessionPad` gained overloads; `PackbinTest.failureCount()` added | AC-12 | stream bytes unchanged (existing session tests pass) | clear |
