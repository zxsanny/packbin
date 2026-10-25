# Expected results — loop 72, frame hardening

Bytes are not new in this loop. Every pair maps onto rows that exist already.

| Input | Expected output | Source |
|-------|-----------------|--------|
| The 157 frame rows (seal, open, refusals, MAC-only) | identical bytes and kinds in C#, Java and Swift | `fixtures/frame/vectors.txt` (PB-03), loop 71 `../../frame-mode-csharp-java-swift/input_data/expected_results/results_report.md` |
| The 27 primitive rows (HKDF, HMAC, ChaCha20) | identical bytes | `fixtures/crypto/vectors.txt` (PB-02) |
| Row E1 sealed in C# with `plain` placed inside `output` (in place, at 0, after `clear`) | the E1 body of `fixtures/frame/vectors.txt` | AC-5.1 |
| C# `Load` with 32-byte key, epoch 0, tag 4, no direction | a session; `Seal` / `Open` in directions 1 to 3 give `BadValue`, 0 bytes written | AC-4; Java `FrameSession.load(key, 0, 4)` gives the same |
| Stream session vectors | unchanged | `scripts/loop-tests.sh` stages `csharp`, `java`, `swift`, `ring` |
