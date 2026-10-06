# Python PackSession seed check on every path; star-import keeps builtins

**Task**: AZ-2104_python_session_star_import
**Name**: Python seed check and safe star-import
**Description**: A `PackSession` can never exist with a seed other than 32 bytes, and `from packbin import *` no longer replaces the caller's `bool`, `bytes`, `dict` and `list`.
**Complexity**: 1 point
**Dependencies**: None
**Component**: python
**Tracker**: AZ-2104
**Epic**: AZ-2069

## Problem

**1. The seed check can be bypassed.**
- The contract (`_docs/02_document/contracts/library/pack-session.md`) says: "Load | 32 bytes | … | length other than 32 creates 0 sessions".
- `PackSession.load` enforces it (`_session.py:27-32`, returns `None`). The constructor `PackSession(seed)` is public and does not (`_session.py:20-25`).
- Reproduced on `d108141`: `PackSession(b"abc").start()` returns 16 bytes and opens a session keyed from a 3-byte seed. HKDF accepts any length, so nothing fails later.
- TypeScript makes the constructor private (`index.ts:138`), so only `load` can create a session there.

**2. Star-import shadows builtins.**
- `__all__` (`__init__.py:36-71`) lists `"bool"`, `"bytes"`, `"dict"`, `"list"`. After `from packbin import *`, a caller's `dict()`, `list(...)`, `bytes(...)` and `bool(...)` are packbin field builders.
- Reproduced: after `from packbin import *`, `dict()` raises `TypeError: dict() missing 2 required positional arguments: 'acc' and 'element'`, and `bytes.fromhex` raises `AttributeError: 'function' object has no attribute 'fromhex'`.
- The README already avoids the clash by writing `from packbin import dict as map_field`. No test or driver uses `import *` (checked `python/tests`, `.github/workflows/drivers/*.py`).

## Outcome

- Every way of creating a `PackSession` refuses a seed that is not exactly 32 bytes. `load` still returns `None`, as the contract says; direct construction raises `ValueError`.
- `from packbin import *` imports every public name except `bool`, `bytes`, `dict`, `list`. Those four stay importable by name (`from packbin import dict as map_field`, `packbin.list`).
- Session bytes and the C# ciphertext vector are unchanged.

## Scope

### Included
- Seed-length check on direct construction.
- Removing the four builtin-shadowing names from `__all__` only.

### Excluded
- Renaming `bool`/`bytes`/`dict`/`list` (a public API change across the README and six packages; not decided).
- Wiping the immutable `bytes` copy made inside `load` (no AC).
- Rust session errors (task 36).

## Acceptance Criteria

**AC-1: wrong-size seed via constructor**
Given seeds of 0, 3, 31 and 33 bytes
When `PackSession(seed)` is called
Then each raises `ValueError` and no session object is returned

**AC-2: load unchanged**
Given the same seeds, and a 32-byte seed
When `PackSession.load(seed)` is called
Then the wrong sizes return `None` and the 32-byte seed returns a session

**AC-3: session vector unchanged**
Given the existing session test seed and nonce
When the opener packs the position row
Then the ciphertext equals the C# vector (`test_ac1_ciphertext_matches_csharp`) and the waiter recovers the five fields

**AC-4: star-import keeps builtins**
Given a fresh module that runs `from packbin import *`
When it calls `dict()`, `list()`, `bytes.fromhex("00")` and `bool(1)`
Then they behave as the Python builtins, and `Scheme`, `BinaryPacker`, `PackSession`, `u8`, `flags`, `utf8` are available

**AC-5: explicit imports still work**
Given `from packbin import dict as map_field, list as list_field, bytes as raw, bool as flag_bool`
When the README dictionary example is packed
Then the bytes are `0102000100610201006201`

## Non-Functional Requirements

**Compatibility**
- No wire change. Callers that relied on `import *` for the four names must import them by name.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-1 | `test_constructor_rejects_wrong_seed_length` | `b"abc"`, 0/31/33 bytes | `ValueError` (today: session opens) |
| AC-2 | `test_ac4_bad_lengths_create_nothing` (existing) | unchanged | still passes |
| AC-4 | `test_star_import_keeps_builtins` | `exec("from packbin import *; dict(); bytes.fromhex('00')", ns)` | no error (today `TypeError`) |
| AC-5 | `test_builder_names_import_explicitly` | README dict example | `0102000100610201006201` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | language-pair `session` handoff (C# opener → Python waiter, TS → Python) | unchanged run | pass, same hex | pack-session contract |
| AC-5 | `.github/workflows/drivers/handoff.py`, `position.py` (explicit imports) | unchanged | pass | project AC-3 |

## Constraints

- ADR-001: Python only.
- The session contract is unchanged: `load` returns `None` for a wrong length.
- No new dependency.

## Risks & Mitigation

**Risk 1: A script used `from packbin import *` and called `dict(...)` as a field builder**
- *Risk*: It now calls the builtin.
- *Mitigation*: The README never shows a star-import. Mention it in the v0.2.0 release notes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Star-import change alters the public `__all__` (four names leave it) | user / release owner | open | Low |
| `ValueError` from the constructor vs `None` from `load`: two failure styles for one rule. Kept because the contract fixes `load` | C15 | accepted-risk | Low |
