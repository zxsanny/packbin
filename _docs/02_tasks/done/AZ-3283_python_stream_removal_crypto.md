---
loop: 74
branch: dev
---

# Python without the stream session; crypto kept and verified

**Task**: AZ-3283_python_stream_removal_crypto
**Name**: Remove `PackSession` from the Python package and keep its crypto as an internal module on the 27 crypto rows
**Description**: Python has no stream session; its SHA-256, HMAC, HKDF and ChaCha20 are ready for the frame port.
**Complexity**: 3 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 03_python_package
**Tracker**: AZ-3283
**Epic**: AZ-3199

## Problem

`python/src/packbin/_session.py` is the stream session (ADR-009 removes it). Its pad module holds the package's only HKDF and ChaCha20, which the frame port (loop 75) needs (D2), and none of it is checked against `fixtures/crypto/vectors.txt`.

## Outcome

- 0 public stream-session names; the crypto lives in an internal module (not in `__all__`) that passes 27 of 27 crypto rows.

## Scope

### Included
- Delete `_session.py`, `tests/test_session.py`, `test_session_pad_after_type.py`, `test_session_payload_type.py`; `__init__.py` and `__all__` lose `PackSession`.
- The pad module becomes an internal crypto module (SHA-256 and HMAC through the standard library, HKDF-SHA256, ChaCha20 block and XOR); a new test reads all 27 rows of `fixtures/crypto/vectors.txt`.
- `_scheme.py`: the `unpad` path of `BinaryPacker._receive`.
- Mixed tests keep their non-session halves: `test_ecc_session_text_dispatch.py` (renamed; EC-11, EC-16 stay), `test_ecc_dispatch_order.py`, `test_hostile_unpack.py`, `test_star_import.py`.
- `fixtures/hostile/fuzz/python/` probes: session parts out.

### Excluded
- Frame mode itself (AZ-3294, loop 75); README (AZ-3291); the Python ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given `import packbin`
When `dir(packbin)` and `packbin.__all__` are read
Then 0 stream-session names are present

**AC-2: Crypto verified**
Given `fixtures/crypto/vectors.txt`
When the new crypto test runs
Then 27 of 27 rows pass (SHA-256 6, HMAC 8, HKDF 3, ChaCha20 block 6, XOR 4), and a row with one changed hex digit fails (1 of 1 mutant caught)

**AC-3: Suite green, no dependency**
Given the Python suite
When it runs
Then 0 tests fail, the clear and ECC tests of mixed files still run, and `pyproject.toml` lists 0 runtime dependencies

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | star-import test | 0 session names |
| AC-2 | crypto vector test plus mutant | 27/27; mutant caught |
| AC-3 | the Python suite | 0 failures |

## Constraints

- The crypto module is internal (leading underscore, not exported); its public use comes with frame mode (AZ-3294).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The crypto module has no caller until the frame port | owner D2: kept, tested on the crypto rows | accepted-risk | Low |
