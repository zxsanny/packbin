---
loop: 69
branch: dev
---

# Primitive reference vectors: Python check and Rust test

**Task**: AZ-3201_primitive_vectors_python_and_rust
**Name**: Reference vectors for SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 (PB-02, Rust first)
**Description**: The published test vectors of the four primitives sit in one fixture, a standard-library Python check re-derives them, and the Rust package matches every row.
**Complexity**: 3 points
**Dependencies**: None
**Component**: fixtures and scripts; Rust session primitives (tests only)
**Tracker**: AZ-3201
**Epic**: AZ-3199

## Problem

The primitives exist privately in all eight packages because the stream session uses them; only C# and Swift test the RFC 8439 block vector, and no package was found testing RFC 4231, RFC 5869 or the FIPS 180-4 SHA-256 examples (recheck on intake). Frame mode authenticates with these primitives, so each must be proven alone first: a wrong primitive that round-trips with itself would pass every frame test in one language and fail only in the cross-language ring. The owner narrowed the spec on 2026-10-25: this task covers the fixture, the Python check and the Rust test; the other seven packages follow. Full spec: `_docs/02_task_plans/rust-m33f-and-frame-mode/input/PB-02_primitive_reference_vectors.md`.

## Outcome

- `fixtures/crypto/vectors.txt`: the published rows (FIPS 180-4: empty, "abc", the 56-byte message, one million `a`; RFC 4231 §4.2 to §4.8 cases 1 to 7 with case 5 truncated to 128 bits; RFC 5869 A.1 to A.3 PRK and OKM; RFC 8439 §2.3.2 and A.1 blocks 1 to 5, §2.4.2 and A.2 ciphers 1 to 3) plus two `derived` rows (SHA-256 of 55 and 64 bytes of `0x61`; HMAC with a 65-byte key), each naming its source section.
- `fixtures/crypto/README.md`, `scripts/crypto/check_vectors.py` and `scripts/crypto/chacha20.py` (Python 3.9+, standard library only), `check-vectors.test.sh` proving the check fails on a corrupted copy.
- The Rust suite reads the file through a test-only hook and matches every row; the primitives stay private.

## Scope

### Included
- The fixture, README, check scripts and their test; one Rust test per primitive; wiring in `scripts/loop-tests.sh` and the existing CI job (as the ECC fixtures are).

### Excluded
- The other seven packages (follow-up, owner 2026-10-25).
- Making the primitives public; frame-mode vectors (AZ-3202).

## Acceptance Criteria

**AC-1: Rust rows match**
Given `fixtures/crypto/vectors.txt`
When the Rust suite runs
Then every SHA-256, HMAC-SHA256, HKDF and ChaCha20 row matches byte for byte: 0 mismatched rows

**AC-2: The tests are not vacuous**
Given a copy of the file with 1 expected byte changed in each primitive's rows
When the Rust suite and `check_vectors.py` run on it
Then each reports the failing row (4 of 4 primitives)

**AC-3: The rows are the published ones**
Given the file
When `check_vectors.py` runs
Then every non-`derived` row names an RFC or FIPS section and the `hashlib`/`hmac` recomputation matches: 0 unmatched rows

**AC-4: Pure-Python ChaCha20 is proven**
Given `scripts/crypto/chacha20.py`
When `check_vectors.py` runs
Then it reproduces every RFC 8439 row: 0 mismatches

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | every row through the Rust private primitive | byte-identical |
| AC-2 | one changed expected byte per primitive | failure reported with the row |
| AC-3 | source field present, recomputation | matches |
| AC-4 | RFC 8439 rows through `chacha20.py` | matches |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-3, AC-4 | HEAD with the change | `check-vectors.test.sh` | passes; the corrupted copies fail | — |
| AC-1 | HEAD with the change | Rust suite with default features and with `--no-default-features --features session` | all rows match | — |

## Constraints

- No change to stream-mode bytes or public API; the Rust `no_std` size figures of the existing sets are unchanged (tests only).
- The 1,000,000-byte SHA-256 row is generated in the test from `repeat` and `byte`, not stored.
- Row syntax stays close to `fixtures/ecc/vectors.txt`; the Python check is the one published rows' reference.
- Fit decision 2: the stream code of `session_core` is read by the test hook, not changed.

## Risks & Mitigation

**Risk 1: A transcription error in a copied vector**
- *Mitigation*: AC-3: an independent implementation recomputes every row before any package test trusts it.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| PB-02 names all eight packages; this task covers Rust only | owner, 2026-10-25 | accepted-risk (follow-up task for the other seven) | Medium |
