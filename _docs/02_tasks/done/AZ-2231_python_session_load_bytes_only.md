# Python `PackSession.load` returns None for a seed that is not bytes-like

**Task**: AZ-2231_python_session_load_bytes_only
**Name**: Python `PackSession.load` takes only a bytes-like seed
**Description**: `PackSession.load(seed)` returns `None`, and raises nothing, for anything that is not a `bytes`, `bytearray` or `memoryview` of exactly 32 bytes, so an integer, a string or a list can no longer open a session.
**Complexity**: 1 point
**Dependencies**: AZ-2104_python_session_star_import (seed length check on the constructor; `load` kept as it was)
**Component**: python
**Tracker**: AZ-2231
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment (`_docs/loops/loop16/assessment16.md` Q2), owner decision A on 2026-10-06. `load` is meant to return `None` for a seed that is not 32 bytes (`_docs/02_document/contracts/library/pack-session.md`: a length other than 32 creates no session). It starts with `bytes(seed)` (`python/src/packbin/_session.py`, `load`), and `bytes(x)` turns many things that are not bytes into bytes. Observed on `2eb9875` (Python 3.14.6):

| Call | Today |
|------|-------|
| `PackSession.load(32)` | a session keyed by 32 zero bytes: with nonce `01000000000000000000000000000000` and a scheme of one `u8`, `{a: 5}` packs `46bb`, exactly what `PackSession.load(bytes(32))` packs |
| `PackSession.load(33)`, `load(0)`, `load(True)` | `None` |
| `PackSession.load([7] * 32)`, `load(tuple(range(32)))`, `load(range(32))`, `load(array('B', range(32)))` | a session |
| `PackSession.load("a" * 32)` | raises `TypeError: string argument without an encoding` |
| `PackSession.load(None)`, `load(32.0)` | raises `TypeError: cannot convert 'NoneType' object to bytes` / `'float' object to bytes` |
| `PackSession(32)` | raises `TypeError: object of type 'int' has no len()` (the constructor, since AZ-2104) |

A mistake such as passing a length instead of the seed gives a session whose key anyone can derive, and the Python component description lists it as a known limitation ("only a bytes-like seed is meant"). AZ-2104 says `load` is unchanged, so no spec covers it.

## Outcome

- `PackSession.load(seed)` returns a session only for a `bytes`, `bytearray` or `memoryview` (or an instance of a subclass) of exactly 32 bytes, counted in bytes as today.
- For anything else it returns `None`. It never raises for the type of its argument (today a string, `None` and a float raise `TypeError`).
- The constructor, the session bytes and the cross-language session vectors are unchanged.

## Scope

### Included
- The type check in `PackSession.load` (`python/src/packbin/_session.py`).
- The Python description known limitation about `load` of an `int` (`_docs/02_document/components/03_python_package/description.md` §7), its `tests.md` row for `test_session`, and the README Python upgrade sentence that says `PackSession.load` "still returns `None`" (README, "Python changed in several places").

### Excluded
- The constructor `PackSession(seed)`: its checks and errors stay as AZ-2104 left them. It still builds a session from a list of 32 integers (`PackSession([7] * 32)` today), which is the same kind of hole; it is reported, not changed here.
- Other buffer-protocol objects (`array.array`, NumPy arrays): they are not among the three types named by the signature and now return `None` (see Risks).
- `start`, `join`, `pack`, `unpack` and the pad derivation.

## Acceptance Criteria

**AC-1: An integer is not a seed**
Given `PackSession.load(32)`
When it is called
Then it returns `None` (today a session keyed by `bytes(32)`).

**AC-2: Wrong sizes still return None**
Given `load(33)`, `load(0)`, `load(True)`, `load(bytes(31))`, `load(bytes(33))`, `load(b"")` and `load(memoryview(b""))`
When they are called
Then each returns `None`, as today.

**AC-3: Anything else that is not bytes-like returns None and raises nothing**
Given `"a" * 32`, `None`, `32.0`, `[7] * 32`, `tuple(range(32))`, `range(32)` and `array('B', range(32))`
When each is passed to `PackSession.load`
Then each returns `None` (today the first three raise `TypeError` and the last four return a session).

**AC-4: A bytes-like seed of 32 bytes still opens a session**
Given `bytes(range(1, 33))`, `bytearray(range(1, 33))`, `memoryview(bytes(range(1, 33)))`, `memoryview(bytes(64))[::2]` and `memoryview(array('I', range(8)))`
When each is passed to `PackSession.load`
Then each returns a session, as today (the length is the number of bytes), and for `bytes(range(1, 33))` the opener packs the position row to `b55d0a29c56c203712b241232e` with nonce `01000000000000000000000000000000` (the C# vector, `test_ac1_ciphertext_matches_csharp`).

**AC-5: The constructor is unchanged**
Given `PackSession(32)` and `PackSession(bytes(31))`
When they are called
Then the first raises `TypeError` and the second `ValueError` with the text `seed must be 32 bytes, got 31`, as today.

## Non-Functional Requirements

**Compatibility**
- No wire change. A caller that passed anything but `bytes`, `bytearray` or `memoryview` now gets `None`; the position vector and the language-pair `session` hand-offs (`.github/workflows/drivers/handoff.py` passes `bytes`) are unchanged.

**Security**
- A seed that is not bytes can no longer produce a session whose key is derived from its length or from small integers.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | `load(32)` | `None` | `python/tests/test_session.py` |
| AC-2 | the seven wrong sizes and values | `None` each (extends `test_load_returns_none_for_a_wrong_seed_length`) | `python/tests/test_session.py` |
| AC-3 | string, `None`, float, list, tuple, range, `array('B')` | `None` each, no exception | `python/tests/test_session.py` |
| AC-4 | `bytes`, `bytearray`, three `memoryview` shapes | a session each; the `bytes` one packs the vector | `python/tests/test_session.py` (extends `test_load_and_constructor_open_the_same_session_for_a_32_byte_seed`; `test_ac1_ciphertext_matches_csharp` is unchanged) |
| AC-5 | `PackSession(32)`, `PackSession(bytes(31))` | `TypeError`; `ValueError` `seed must be 32 bytes, got 31` | `python/tests/test_session.py` (extends `test_constructor_rejects_wrong_seed_length`) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | language-pair `session` hand-offs, Python as opener and waiter (`.github/workflows/drivers/handoff.py`) | unchanged run | same ciphertext, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Python only; no cross-package import.
- Files at or under 500 lines (`_session.py` is 83, `test_session.py` 132).
- Error kind and label of existing errors unchanged (decision C15): the constructor errors above stay; `load` adds no new error, it returns `None`.
- No new dependency; the return type stays `PackSession | None` and the parameter annotation stays `bytes | bytearray | memoryview`.
- Probe results in the Problem table come from running the code at `2eb9875`; the target results of AC-1 to AC-4 come from a throwaway `isinstance` check on a scratch copy (the 13 tests of `test_session.py` pass with it). The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: Callers that passed another buffer object or a list of integers**
- *Risk*: `array.array('B', ...)`, a NumPy `uint8` array or a list of 32 integers opened a session before; now `load` returns `None`.
- *Mitigation*: `bytes(...)` around the value restores it. The README Python upgrade note names it. The three accepted types are the ones the signature already declares.

**Risk 2: `None` hides a type mistake that raised before**
- *Risk*: a string or `None` raised `TypeError` and now gives `None`, which a caller may not check.
- *Mitigation*: it is the existing "bad seed gives `None`" rule, and `load` already returns `None` for a wrong length; the owner chose this over raising (option B).

## Owner decision (2026-10-06)

DECIDED, assessment Q2 option A (the recommendation, "implement everything now"): `PackSession.load` returns `None` for anything that is not bytes-like (`bytes`, `bytearray`, `memoryview`) of exactly 32 bytes, and raises no exception. The constructor and the cross-language session vectors are unchanged.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2). `PackSession.load(seed)` returns a session only for `bytes`, `bytearray` or `memoryview` (or a subclass) of exactly 32 bytes and `None` for anything else, and no longer raises `TypeError` for a `str`, `None` or a float. An `int`, a list or tuple of ints, a range and an `array.array` no longer open a session (`load(32)` opened one keyed by 32 zero bytes). `python/src/packbin/_session.py`: an `isinstance` guard before `bytes(seed)`; the constructor and the session bytes are unchanged.

Tests (`python/tests/test_session.py`, 24 new): AC-1 `test_ac1_load_of_an_integer_returns_none`; AC-2 `test_ac2_wrong_sizes_and_values_still_return_none` (7 cases); AC-3 `test_ac3_anything_not_bytes_like_returns_none_and_raises_nothing` (7 cases); AC-4 `test_ac4_a_bytes_like_seed_of_32_bytes_opens_a_session` (bytes, bytearray, three memoryview shapes, a bytes subclass) and `test_ac4_the_bytes_seed_packs_the_csharp_vector` (`b55d0a29c56c203712b241232e`); AC-5 `test_ac5_the_constructor_keeps_its_errors`; review fix `test_ac3_a_released_memoryview_returns_none_and_raises_nothing`. Eight of the first 23 failed at HEAD. Suite 326 passed.

Evidence: the reviewer's 35-input probe matches the spec: a session for bytes, bytearray and memoryview (read-only, strided, 2-D, items wider than a byte) and their subclasses; `None` for `array.array`, ctypes, mmap, `__bytes__` objects, a zero-dimensional view, `str`, `None`, `int`, `float`, `list`, `tuple`, `range`, `set`, `dict`, `object` and a huge int. Removing the `isinstance` guard fails `test_ac1` and seven `test_ac3` cases.

Review finding F2 (low): `load` of a released `memoryview` raised `ValueError` from `bytes(seed)`. Fixed: `load` catches that one `ValueError` and returns `None`, with a one-line comment; the new test failed before the fix. A hostile `__bytes__` still propagates (the caller's own code).

Open (spec Excluded, owner): `PackSession([7] * 32)` and a 2-D memoryview still build through the constructor; `None` hides a type mistake that raised before (the owner chose `None` over raising, Risk 2). A caller that does not check `None` fails later at `start` or `pack`; `bytes(...)` restores an `array.array`, NumPy or list seed. Documented in the README patch and the Python description.
