---
loop: 71
branch: dev
---

# Loop 71: frame mode in C#, Java and Swift (AZ-3192 follow-up)

Intake stub. Phase 1 grasp only; Phases 2 to 4 follow in this loop.

## What

Frame mode (session contract 2.0.0, ADR 008) shipped in Rust only (loop 69, epic AZ-3199). meshbell's first other consumers are the C# server, Android (through Java) and iOS (through Swift). This loop brings the same frame mode to those three packages: `seal` / `open` with the key schedule, the replay window, the previous-key slot and the MAC-only call, byte for byte equal to the contract, checked against the shared `fixtures/frame/vectors.txt` (PB-03) and the primitive vectors of `fixtures/crypto/vectors.txt` (PB-02).

Owner choice (2026-10-25, loop 71 start, recommended option): "Frame mode in C#, Java, Swift".

## Code sections / UI locations for this loop

Owner words: "continue implementation" after picking the option that names the session modules of the three packages.

- C#: `csharp/PackSession.cs` (stream session), `csharp/Compat.cs` (where the stream pad primitives live), the C# test project.
- Java: `java/src/main/java/packbin/PackSession.java`, `SessionPad.java`, the Java tests.
- Swift: `swift/Sources/Packbin/PackSession.swift`, `SessionKeys.swift`, `swift/Tests/PackbinTests/`.
- Shared, read only: `fixtures/frame/vectors.txt`, `fixtures/crypto/vectors.txt`, `_docs/02_document/contracts/library/pack-session.md` (2.0.0), the Rust reference in `rust/src/nostd` and `rust/src/session_core`, `scripts/frame/framefmt.py`.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| Which of the three packages first, and whether all three fit one loop | owner | open (Phase 2) | Medium |
| PB-02 primitive vector tests in these three packages come with the frame work | owner (loop 69 narrowed PB-02 to Rust) | open (Phase 2) | Low |
| Constant-time tag compare and key wipe differ by runtime (GC, JIT, ARC) | each package's best effort, stated in the doc | open | Medium |
| Replay window value type per language (unsigned 64) | contract fixes the bits | open | Low |
