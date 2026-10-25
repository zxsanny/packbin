# Blackbox Tests 24: frame mode in C#, Java and Swift (loop 71, FT-X-163 to FT-X-165)

Source: `_docs/02_task_plans/frame-mode-csharp-java-swift/` (acceptance_criteria.md, scenarios.md S1 to S13), tasks AZ-3232, AZ-3233, AZ-3234, AZ-3235.

## FT-X-163: shared vectors through the public API of three packages

| Item | Value |
|------|-------|
| Input | `fixtures/frame/vectors.txt` (157 rows, E1 to E5, boundary and refusal rows) and `fixtures/crypto/vectors.txt` (27 rows) |
| Expected | every output field of every row matches in C# (`net10.0` and `netstandard2.0`), Java and Swift; a copy with one expected byte changed fails naming the row; the bodies equal the Rust ones |
| Run by | C# `FrameVectorTests`, `CryptoVectorTests`; Java `FrameVectorsTest`, `CryptoVectorsTest`; Swift `FrameVectorTests`, `CryptoVectorTests` |
| Not run by | Python, TypeScript, C++, Go (later tasks) |

## FT-X-164: tampering, replay before crypto, previous slot, MAC-only, hostile input

| Item | Value |
|------|-------|
| Input | E1 to E3 with every single bit flipped; seen and too-old counters; a session at (B, 7) with previous (A, 6); the MAC-only call over 1, 2, 3 parts; 1,000 seeded random bodies, lengths and `clear_len` |
| Expected | `TagMismatch` with the output buffer untouched and the window unchanged; `Duplicate` and `TooOld` with 0 MAC computations; `Previous` / `Current` / `TagMismatch`; one tag for every split; 0 unhandled exceptions or crashes |
| Run by | the tamper, replay, MAC and hostile test classes of each package |

## FT-X-165: lifecycle, concurrency and README examples

| Item | Value |
|------|-------|
| Input | a session released then used; 8 threads sealing 1,000 distinct `msg_id`s; the README example of each language |
| Expected | key arrays read zero after release and the call is `BadValue`; every body equals the single-thread seal; the README block equals the example test (`scripts/frame/readme-examples.sh`) |
| Run by | wipe / lifecycle / concurrency test classes (Swift under the thread sanitizer); the README check in `test.yml` |
| Not run by | a real Android or iOS device |
