# Expected results — loop 74, remove the stream session

This loop adds no new wire behavior. Its expected results are the existing shared fixtures, which must give the same answers after the removal and the renames.

| Input | Expected output | Packages | AC |
|-------|-----------------|----------|----|
| `fixtures/frame/vectors.txt`, 157 rows (seal, open, MAC-only, refusals) | each row's recorded body, result and error kind | Rust, C#, Java, Swift | AC-2 |
| `fixtures/crypto/vectors.txt`, 27 rows (SHA-256, HMAC-SHA256, HKDF-SHA256, ChaCha20 block and XOR) | each row's recorded digest, MAC, key or keystream | all 8 (C++, Go, Python, TypeScript new) | AC-5 |
| `fixtures/golden.hex` | the recorded packed bytes of each scheme | all 8 | AC-3 |
| `fixtures/ecc/` | the recorded parity bytes and repairs | all 8 | AC-3 |
| ring clear and ECC stages (`.github/workflows/language-pair.sh`) | every driver unpacks every other driver's bytes | all 8 | AC-3 |

Removed rows: the stream-session ciphertext (`b55d0a29…`, the C# session vector used by every package's session tests and the ring's `pack-session` and `pack-session-ecc` stages) has no consumer after this loop; `fixtures/hostile/fuzz/corpus.txt` keeps its `ring_session` line as plain hostile input.
