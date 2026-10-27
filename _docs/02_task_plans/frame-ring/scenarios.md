# Scenarios: frame ring (loop 77)

Source: `_docs/loops/loop77/assessment77.md` (round 1). Status values: confirmed, out-of-scope, deferred.

| id | scenario | status | AC ref | note |
|----|----------|--------|--------|------|
| S1 | Seal in directions 1, 2, 3, opened by every language | confirmed | AZ-3338 AC-2 | covered |
| S2 | Tag lengths 4, 8, 16 | confirmed | AZ-3338 AC-2 | covered |
| S3 | Clear part absent and 3 bytes | confirmed | AZ-3338 AC-2 | covered |
| S4 | Plaintext of 0, 12, 20, 42 bytes | confirmed | AZ-3338 AC-2 | covered |
| S5 | MAC compute and verify, n = 8 and 16 | confirmed | AZ-3338 AC-3 | covered |
| S6 | A wrong output of one language fails the ring | confirmed | AZ-3338 AC-4, AC-5 | covered |
| S7 | A fixture row the reference does not confirm stops the run | confirmed | AZ-3338 AC-4 | covered |
| S8 | Ring and self-test wired in CI | confirmed | AZ-3338 AC-8 | covered; self-test wired in d0b8525 |
| O1 | Replay window | out-of-scope | - | problem.md "Out of scope" |
| O2 | Key rotation | out-of-scope | - | problem.md "Out of scope" |
| G1 | Tampered body gives TagMismatch / ShortPacket; wrong tag is `invalid` | confirmed | AZ-3341 AC-1, AC-2, AC-8, AC-9 | assess-round-1 |
| G2 | Refusals TooLong, ShortPacket, BadValue by row | deferred | - | leftover; vectors.txt holds 64 refusal rows read by all 8 packages |
| G3 | Direction not loaded or bad, BufferFull | deferred | - | leftover; needs `dirs` / `out_len` columns and driver changes |
| G4 | Plaintext 63, 64, 65, 128, 192, 251; body of 255 | confirmed | AZ-3341 AC-3 | assess-round-1 |
| G5 | Epochs 0, 65535, 16777215 | confirmed | AZ-3341 AC-4 | assess-round-1 |
| G6 | Kinds 0, 8, 15; msg_id edge values | confirmed | AZ-3341 AC-5 | assess-round-1 |
| G7 | AD empty and 255 bytes; clear part of 40 | confirmed | AZ-3341 AC-6 | assess-round-1 |
| G8 | MAC n = 32, labels 1 and 32, empty message, 63/64/65 bytes | confirmed | AZ-3341 AC-7 | multi-part messages excluded (driver line format) |
| G9 | Swift `PackbinError.Kind` comment | confirmed | AZ-3341 AC-10 | assess-round-1 |
| U1 | Key not 32 bytes (Rust), msg_id not 8 bytes (Rust, C++) | out-of-scope | - | owner 2026-10-27: option A, leave out; the types forbid it |
