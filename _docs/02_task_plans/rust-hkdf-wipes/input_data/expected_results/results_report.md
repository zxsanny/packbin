# Expected results — loop 73, Rust wipes

Bytes are not new in this loop. Every pair but the helper's maps onto rows that exist already.

| Input | Expected output | Source |
|-------|-----------------|--------|
| The 27 primitive rows (HKDF, HMAC, ChaCha20) | identical bytes in Rust | `fixtures/crypto/vectors.txt` (PB-02) |
| RFC 5869 case 1: IKM 22 x 0x0b, salt 0x00..0x0c, info 0xf0..0xf9, L = 42 | `3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865` | `rust/src/session_core/hkdf.rs` `rfc5869_case_1` |
| RFC 8439 2.3.2 block: key 0x00..0x1f, nonce 000000090000004a00000000, counter 1 | the RFC's block; the test checks the first 32 bytes, `10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4e` | `rust/src/session_core/pad.rs` `rfc8439_block_vector` |
| The 157 frame rows (seal, open, refusals, MAC-only) | identical bytes and kinds | `fixtures/frame/vectors.txt` (PB-03) |
| Stream session vectors and the cross-language session | unchanged | `scripts/loop-tests.sh` stages `rust`, `ring` |
| The embedded golden packet on the M4F and M33F images | `GOLDEN_OK 1`, `ROUTE_HEX 3434120700030065cd1d…0409` as at HEAD | `rust/embedded/run.sh` rows `rust-m4f`, `rust-m33f` |
| Wipe helper on 64 bytes of 0xA5 and on 16 words of 0xA5A5A5A5 | 64 zero bytes; 16 zero words | AC-1.4 (new unit test) |
