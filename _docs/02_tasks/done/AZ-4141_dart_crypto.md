---
loop: 99
branch: dev
---

# Dart: SHA-256, HMAC, HKDF and ChaCha20 on the shared crypto vectors

**Task**: AZ-4141_dart_crypto
**Name**: Dart: SHA-256, HMAC, HKDF and ChaCha20 on the shared crypto vectors
**Description**: The four primitives frame mode needs, written in the package.
**Complexity**: 3 points
**Dependencies**: AZ-4134_dart_core
**Component**: dart
**Tracker**: AZ-4141
**Epic**: AZ-4133

## Problem

Frame mode derives keys with HKDF-SHA256, tags with HMAC-SHA256 and encrypts with ChaCha20. The package has no dependency (A-4), so the four primitives are written in Dart and proven on the shared vectors, as the other packages prove theirs.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- All 27 rows of `fixtures/crypto/vectors.txt` pass in Dart.
- The primitives are internal: not exported from `packbin.dart`.

## Scope

### Included

- SHA-256, HMAC-SHA256, HKDF-SHA256 (extract and expand) and ChaCha20 (block and keystream XOR with a counter) under `dart/lib/src/crypto*`.
- A loader of `fixtures/crypto/vectors.txt` and one test per primitive.
- Working buffers that held key material are zeroed before return.
- Owns: `dart/lib/src/crypto*`, `dart/test/crypto*`.

### Excluded

- Frame mode (AZ-4142)
- `fixtures/crypto/README.md` loader line (AZ-4148)

## Acceptance Criteria

**AC-1: Vectors (DT-19)**
Given the 27 rows (sha256, hmac256, hkdf256, chacha-block, chacha-xor)
When run in Dart
Then the row's digest, tag, key material, block or text; mismatched bytes 0

**AC-2: 32-bit arithmetic**
Given inputs whose words reach 2^32 - 1 (the all-ones key and the counter 2^32 - 1 rows)
When hashed or encrypted
Then the vector's bytes: every add and rotate is masked to 32 bits (a Dart `int` is 64-bit and does not wrap at 32)

**AC-3: Empty input (zero value)**
Given an empty message for SHA-256 and HMAC, an empty text for ChaCha20, HKDF with an empty salt and info
When run
Then the vector's output for the empty rows; an empty text gives an empty result

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Vectors: the 27 rows (sha256, hmac256, hkdf256, chacha-block, chacha-xor) | the row's digest, tag, key material, block or text; mismatched bytes 0 |
| AC-2 | 32-bit arithmetic: inputs whose words reach 2^32 - 1 (the all-ones key and the counter 2^32 - 1 rows) | the vector's bytes: every add and rotate is masked to 32 bits (a Dart `int` is 64-bit and does not wrap at 32) |
| AC-3 | Empty input: an empty message for SHA-256 and HMAC, an empty text for ChaCha20, HKDF with an empty salt and info | the vector's output for the empty rows; an empty text gives an empty result |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- No dependency (DT-11).
- Not exported: the public API offers frame mode, not primitives.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Hand-written crypto**
- *Risk*: A subtle error gives wrong bytes that still round-trip inside Dart.
- *Mitigation*: Only the shared vectors and, later, the frame ring count as proof; no Dart-to-Dart round trip is accepted as a crypto test.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
