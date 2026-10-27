# Primitive reference vectors

The published test vectors of the four primitives of frame mode, packbin's only session (AZ-3201, spec PB-02; `_docs/02_document/contracts/library/pack-session.md` 3.0.0, ADR 009): SHA-256, HMAC-SHA256, HKDF-SHA256 and the ChaCha20 block and cipher. The rows are copied from the publications, not generated, and every one is re-derived by an independent implementation before a package trusts it. All eight packages read all 27 rows: the four with frame mode in `rust/src/crypto_vectors_tests.rs`, `csharp/tests/CryptoVectorTests.cs`, `java/src/test/java/packbin/CryptoVectorsTest.java` and `swift/Tests/PackbinTests/CryptoVectorTests.swift`, and the four whose frame-mode port comes in loop 75 against their internal, unexported crypto module (owner decision D2, loop 74) in `cpp/tests/core/crypto_vectors_host_tests.cpp`, `go/crypto_vectors_test.go`, `python/tests/test_crypto_vectors.py` and `typescript/tests/crypto-vectors.test.ts`.

| File | What it is |
|------|------------|
| `vectors.txt` | The rows. Row syntax is at the top of the file. |
| `check-vectors.sh` | Re-derives every row (`scripts/crypto/check_vectors.py`) and fails on any mismatch, naming the row. |
| `check-vectors.test.sh` | Proves the check passes the committed file and fails on copies with one expected byte changed in the rows of each primitive (SHA-256, HMAC, HKDF, ChaCha20 block and cipher), and on a row with no source. |

## Row syntax

`<primitive> <source> <key=value> ...`, space separated. Bytes are lowercase hex; `-` is the empty byte string. The source is the row id (unique per primitive) and names the publication section.

| Primitive | Fields |
|-----------|--------|
| `sha256` | `msg` (hex) or `repeat` and `byte` (the byte repeated n times, so the million-`a` row is not stored), `digest` |
| `hmac256` | `key`, `data`, `mac`; `truncate=n` compares only the first n bytes of the MAC (RFC 4231 test case 5, 128 bits) |
| `hkdf256` | `ikm`, `salt`, `info`, `len`, `prk` (extract), `okm` (expand, `len` bytes); an empty salt is the RFC's string of zeros |
| `chacha-block` | `key`, `nonce` (12 bytes), `counter`, `block` (64 bytes) |
| `chacha-xor` | `key`, `nonce`, `counter` (the first block), `plain`, `cipher` |

## Sources

| Source | Publication |
|--------|-------------|
| `fips180-4:b.1`, `b.2`, `b.3` | FIPS 180-4 appendix B SHA-256 examples: `abc`, the 56-byte two-block message, one million `a` |
| `nist:empty` | the NIST example value of the empty message |
| `rfc4231:4.2` to `4.8` | RFC 4231 test cases 1 to 7 |
| `rfc5869:a.1` to `a.3` | RFC 5869 appendix A.1 to A.3 (PRK and OKM) |
| `rfc8439:2.3.2`, `a.1.1` to `a.1.5` | the RFC 8439 block example and appendix A.1 block test vectors 1 to 5 |
| `rfc8439:2.4.2`, `a.2.1` to `a.2.3` | the RFC 8439 "Ladies and Gentlemen" cipher example and appendix A.2 test vectors 1 to 3 |
| `derived:a55`, `a64`, `key65` | packbin's own: SHA-256 of 55 and of 64 bytes of `0x61` (padding boundary), HMAC-SHA256 with a 65-byte key (a key longer than the block is hashed first); computed with `hashlib`/`hmac` |

## Checking

`bash fixtures/crypto/check-vectors.sh [file]` and `bash fixtures/crypto/check-vectors.test.sh` (Python 3.9 or newer, standard library only). `scripts/crypto/chacha20.py` is the pure-Python RFC 8439 block and cipher (`block(key, nonce, counter)`, `xor(key, nonce, counter, data)`) that later reference generators import.
