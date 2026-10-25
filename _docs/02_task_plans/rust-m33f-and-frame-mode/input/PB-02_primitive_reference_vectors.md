**Spec 2 of 4: PB-02 (self-contained, 2026-10-25).** Copy into packbin's `_docs/02_tasks/todo/` on intake. Context for the frame mode is in Spec 1 (PB-01).

# Reference vectors for SHA-256, HMAC-SHA256, HKDF and ChaCha20

**Task**: PB-02_primitive_reference_vectors
**Name**: Reference vectors for the session primitives in every package
**Description**: Every package checks its private SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 against the published test vectors, before any frame-mode vector depends on them.
**Complexity**: 3 points
**Dependencies**: None
**Component**: all eight packages (session primitives, tests only), `fixtures/crypto/`, `scripts/crypto/`
**Tracker**: umbrella AZ-3192; packbin gives this task its own AZ id on intake
**Epic**: new packbin epic "Frame mode" (created on intake)

## Problem

The primitives (SHA-256, HMAC-SHA256, HKDF-SHA256, the ChaCha20 block) exist privately in all eight packages because the stream session uses them. Only C# and Swift test the RFC 8439 block vector; no package was found testing RFC 4231 (HMAC-SHA256), RFC 5869 (HKDF) or the FIPS 180-4 SHA-256 examples (meshbell's review of packbin `c20bcd6`, 2026-10-19; recheck on intake). Frame mode authenticates with these primitives (PB-01), so each must be proven on its own first. A wrong primitive that happens to round-trip with itself would pass every frame test in one language and fail only in the cross-language ring.

## Outcome

* `fixtures/crypto/vectors.txt` with the published vectors listed below, copied from the publications (not generated), each row naming its source section.
* `fixtures/crypto/README.md`: row syntax, sources, how to check.
* `scripts/crypto/check_vectors.py` (Python 3.9 or newer, standard library only): re-checks the SHA-256, HMAC and HKDF rows with `hashlib` and `hmac`, and the ChaCha20 rows with a small pure-Python RFC 8439 implementation in `scripts/crypto/chacha20.py` (PB-03 reuses it). `check-vectors.test.sh` proves the check fails on a corrupted copy, as the ECC fixtures do.
* Each package's test suite reads the file through a test-only hook and matches every row. The primitives stay private API.

## Vectors

| Primitive | Source | Rows |
| --- | --- | --- |
| SHA-256 | FIPS 180-4 examples (NIST CSRC "SHA256.pdf", the one-block and two-block messages) and the NIST long message | `""` (empty), `"abc"`, the 56-byte `"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"`, 1,000,000 × `"a"` |
| HMAC-SHA256 | RFC 4231 §4.2 to §4.8 | test cases 1 to 7; case 5 is truncated to 128 bits and is checked as truncated |
| HKDF-SHA256 | RFC 5869 Appendix A.1, A.2, A.3 | PRK and OKM of each case |
| ChaCha20 block | RFC 8439 §2.3.2 and Appendix A.1 | the §2.3.2 block, test vectors 1 to 5 of A.1 |
| ChaCha20 cipher | RFC 8439 §2.4.2 and Appendix A.2 | the §2.4.2 "Ladies and Gentlemen…" example (counter 1), test vectors 1 to 3 of A.2 |

Add two edge rows of packbin's own, derived with `hashlib`/`hmac` and marked `derived`: SHA-256 of 55 and of 64 bytes of `0x61` (padding boundary), and HMAC-SHA256 with a 65-byte key (key longer than the block is hashed first).

## Row syntax (proposal; keep it close to `fixtures/ecc/vectors.txt`)

```
# primitive  source           fields (hex unless noted)
sha256       fips180-4:abc    msg=616263 digest=…
sha256       nist:million-a   repeat=1000000 byte=61 digest=…
hmac256      rfc4231:tc5      key=… data=… mac=… truncate=16
hkdf256      rfc5869:a1       ikm=… salt=… info=… len=42 prk=… okm=…
chacha-block rfc8439:2.3.2    key=… nonce=… counter=1 block=…
chacha-xor   rfc8439:2.4.2    key=… nonce=… counter=1 plain=… cipher=…
```

## Scope

### Included

* The fixture file, its README and the check scripts; one test per package and primitive; CI wiring in the existing per-package jobs

### Excluded

* Making the primitives public API (frame mode exposes them only through seal, open and the MAC-only call)
* Frame-mode vectors (PB-03)

## Acceptance Criteria

**AC-1: All vectors pass in all packages**
Given `fixtures/crypto/vectors.txt`
When each of the eight packages runs its suite  
Then every SHA-256, HMAC-SHA256, HKDF and ChaCha20 row matches byte for byte

**AC-2: The tests are not vacuous**
Given a copy of the file with one expected byte changed in each primitive's rows  
When the suites and `check_vectors.py` run on it  
Then each reports the failing row

**AC-3: The rows are the published ones**
Given the file  
When `check_vectors.py` runs  
Then every non-`derived` row names an RFC or FIPS section, and the reference recomputation matches it

**AC-4: Pure-Python ChaCha20 is proven**
Given `scripts/crypto/chacha20.py`
When `check_vectors.py` runs  
Then it reproduces every RFC 8439 row (PB-03's reference generator depends on it)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
| --- | --- | --- |
| AC-1 | every row through each package's private primitive | byte-identical |
| AC-2 | one changed expected byte per primitive | failure reported with the row |
| AC-3 | source field present, recomputation | matches |
| AC-4 | RFC 8439 rows through `chacha20.py` | matches |

## Constraints

* No change to stream-mode bytes or public API; the Rust `no_std` size report of the existing feature sets is unchanged (tests only).
* The 1,000,000-byte SHA-256 row is generated in the test from `repeat` and `byte`, not stored.
* Standard library only for the Python scripts (packbin's fixture practice).

## Risks & Mitigation

**Risk 1: A transcription error in a copied vector**

* _Mitigation_: AC-3: the reference recomputes every row with an independent implementation (`hashlib`, `hmac`) before any package test trusts it


