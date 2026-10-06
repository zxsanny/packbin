# Python `PackSession.start` and `join` take only a bytes-like nonce

**Task**: AZ-2244_python_session_start_join_bytes_only
**Name**: Python `PackSession.start` and `join` take only a bytes-like nonce
**Description**: `PackSession.start(nonce)` returns `None` and `PackSession.join(nonce)` returns `False`, and neither raises, for anything that is not a `bytes`, `bytearray` or `memoryview` of exactly 16 bytes, so an integer, a list or an `array.array` can no longer open a session and a string, a float, a released memoryview and `join(None)` no longer raise. `start()` and `start(None)` still draw the nonce.
**Complexity**: 1 point
**Dependencies**: AZ-2231_python_session_load_bytes_only (done: the check `load` uses, which `start` and `join` now share)
**Component**: python
**Tracker**: AZ-2244
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment round 2 (`_docs/loops/loop16/assessment16.md`, X2). The contract says "a nonce length other than 16 opens 0 sessions" (Start) and "length other than 16 joins 0 sessions" (Join) (`_docs/02_document/contracts/library/pack-session.md:21-22`). `start` and `join` convert the nonce with `bytes(nonce)` (`python/src/packbin/_session.py`), and `bytes(x)` turns many things that are not bytes into bytes. AZ-2231 closed this for `load`; its Excluded list named `start` and `join` as scope only, not as a decision.

Observed on `35544ed` (`git archive` export, Python 3.14.6). Session: `PackSession.load(bytes(range(1, 33)))`, scheme `Scheme(1, dict, u8(0, lambda r: r["a"]))`, row `{"a": 5}`. "opens" means the session then packs; "closed" means `pack` returns `None`.

| Nonce passed | `start(nonce)` at HEAD | `join(nonce)` at HEAD |
|--------------|------------------------|-----------------------|
| `16` | returns `00000000000000000000000000000000`, opens; the row packs to `518d`, byte for byte what `start(bytes(16))` packs | `True`, opens |
| `15`, `0`, `True` | `None`, closed | `False`, closed |
| `[1] * 16` | returns `01010101010101010101010101010101`, opens, packs `d9b9` | `True`, opens |
| `tuple(range(16))`, `range(16)`, `array('B', range(16))` | returns `000102030405060708090a0b0c0d0e0f`, opens | `True`, opens |
| `(ctypes.c_ubyte * 16)(*range(1, 17))` | returns `0102030405060708090a0b0c0d0e0f10`, opens | `True`, opens |
| an object whose `__bytes__` returns 16 bytes | opens | `True`, opens |
| `"a" * 16` | raises `TypeError: string argument without an encoding` | the same |
| `16.0`, `object()` | raises `TypeError: cannot convert 'float' object to bytes` (`'object' object` for the second) | the same |
| `None` | the documented random form: returns 16 random bytes, opens | raises `TypeError: cannot convert 'NoneType' object to bytes` |
| a released `memoryview` | raises `ValueError: operation forbidden on released memoryview object` | the same |
| a plain object whose `__bytes__` raises `RuntimeError` | the `RuntimeError` propagates | the same |

Two consequences. A caller that passes a length instead of the nonce (`start(16)`) opens a session keyed by a fixed zero nonce, so two sessions with the same seed use the same pad; and the call that was meant to open it (`start(nonce)`) then returns `None` because the session is already open (probe: `start(16)` returned 16 zero bytes, then `start(NONCE)` returned `None` and the pad was the zero-nonce pad). The ticket text and the assessment agree with every row above; the assessment's `d2bf` is the same observation with another seed and scheme.

What `load`, `start` and `join` do for the four inputs the ticket asks about (probe on `35544ed`: `load` gets 32 bytes, `start` and `join` get 16 bytes of the same shape):

| Input | `load` (32 bytes) | `start`, `join` (16 bytes) at HEAD | after this task |
|-------|-------------------|------------------------------------|-----------------|
| released `memoryview` | `None` (AZ-2231 review fix) | `ValueError` raised | `None` / `False`, as `load` |
| plain object with a hostile `__bytes__` | `None`, `__bytes__` never called | `RuntimeError` raised from `__bytes__` | `None` / `False`, `__bytes__` never called |
| a `bytes` subclass | a session | opens | opens |
| a 2-D `memoryview` (`.cast("B", shape=[4, 4])`; 16 bytes in all) | a session: the length is counted in bytes, not rows | opens (the same 16 bytes as `bytes(view)`) | opens |
| a `bytes` or `bytearray` subclass whose `__bytes__` raises | the `RuntimeError` propagates | the same | the same in all three (see Risks) |

So the three differ today only in `start` and `join` raising or opening where `load` returns `None`; after this task the three give the same verdict for every input in the table.

## Outcome

- `PackSession.start(nonce)` with a `bytes`, `bytearray` or `memoryview` (or an instance of a subclass) of exactly 16 bytes, counted in bytes as today, opens the session as the opener and returns the 16 bytes as `bytes`.
- For any other `nonce` other than `None`, `start` returns `None`, raises nothing, and the session stays closed (a later valid `start` or `join` still opens it).
- `PackSession.join(nonce)` returns `True` for the same three types of exactly 16 bytes, and `False` for anything else, raises nothing, and the session stays closed. `join(None)` is `False` (it raised `TypeError`).
- `start()` and `start(None)` still draw 16 random bytes and open the session.
- `load`, `start` and `join` share one check, so the three agree on every input (type, released view, 2-D view, length in bytes). The constructor, the pad derivation, the session bytes and the cross-language session vectors are unchanged.

## Scope

### Included
- One private check in `python/src/packbin/_session.py` (an `isinstance` test for `bytes`, `bytearray`, `memoryview`, the existing `ValueError` catch for a released view, then the length in bytes) used by `load`, `start` and `join`; `load` keeps exactly the behaviour AZ-2231 gave it.
- The docs pass, with these sentence proposals:
  - README, "Python changed in several places" (the paragraph that says `PackSession.load` "returns `None` ... for anything that is not a `bytes`, `bytearray` or `memoryview`"): add "`PackSession.start(nonce)` and `join(nonce)` follow the same rule: a nonce that is not a `bytes`, `bytearray` or `memoryview` of 16 bytes makes `start` return `None` and `join` return `False` and raises nothing, where `start(16)`, a list of 16 integers or an `array.array` opened a session (keyed by that nonce) and a `str`, a float, a released `memoryview` and `join(None)` raised; `start()` and `start(None)` still draw the nonce." and change the last sentence to "In calling code, import the four names explicitly, and give `PackSession.load`, `start` and `join` `bytes(...)` values."
  - `_docs/02_document/components/03_python_package/description.md` §Interface PackSession: the `start` row Inputs "none, or `bytes`, `bytearray` or `memoryview` of 16 bytes" and Failure "anything else returns `None` and raises nothing, and the session stays closed: a length other than 16, an `int`, a list, a `str`, a released memoryview (loop 16, AZ-2244)"; the `join` row the same with `False`; the known-limitation line that says `load` "is the strict entry point" becomes "`load`, `start` and `join` are the strict entry points (bytes, bytearray or memoryview only)"; the `load` bullet in the changes list gains "`start(16)` and `join(16)` opened a session too (AZ-2244)".
  - `_docs/02_document/components/03_python_package/tests.md`: a `test_session` row for AZ-2244 next to the AZ-2231 row.

### Excluded
- The constructor `PackSession(seed)`: it still builds a session from a list of 32 integers (AZ-2231 Excluded, assessment O19); reported, not changed.
- A `bytes` or `bytearray` subclass whose own `__bytes__` raises or returns other bytes: `bytes(value)` calls it in `load`, `start` and `join` alike today and keeps doing so (Risk 3).
- Other buffer-protocol objects (`array.array`, ctypes, NumPy): not among the three named types; they now give `None` / `False` as for `load` (Risk 1).
- `pack`, `unpack`, the pad derivation, and every other package (TypeScript throws `TypeError: "key" expected Uint8Array` for these inputs, from the assessment; not re-probed here and not changed).

## Acceptance Criteria

Every value below was produced on `35544ed` (the HEAD results) and in a throwaway copy of the check on a scratch export (the target results; the 326 existing Python tests pass with it). The worker re-derives them from a real run. Common setup: `S = PackSession.load(bytes(range(1, 33)))`, `NONCE = 01000000000000000000000000000000`.

**AC-1: `start` refuses a nonce that is not bytes-like**
Given `16`, `15`, `0`, `True`, `[1] * 16`, `tuple(range(16))`, `range(16)`, `"a" * 16`, `16.0`, `array('B', range(16))`, `(ctypes.c_ubyte * 16)(*range(1, 17))`, `object()` and an object whose `__bytes__` returns 16 bytes
When each is passed to `start` on a fresh `S`
Then each call returns `None`, raises nothing, and `S.pack(...)` still returns `None` (HEAD: `16`, the list, tuple, range, `array`, ctypes and `__bytes__` objects open a session; `"a" * 16`, `16.0` and `object()` raise `TypeError`).

**AC-2: `join` refuses a nonce that is not bytes-like**
Given the same thirteen values and `None`
When each is passed to `join` on a fresh `S`
Then each call returns `False` (the value `False`, not a falsy one), raises nothing, and the session stays closed (HEAD: `16`, the list, tuple, range, `array`, ctypes and `__bytes__` objects return `True`; `"a" * 16`, `16.0`, `object()` and `None` raise `TypeError`).

**AC-3: A refused call leaves the session closed and usable**
Given `S.start(16)` returned `None` (and, on a second session, `join(16)` returned `False`)
When `S.start(NONCE)` and `join(NONCE)` are then called
Then `start(NONCE)` returns `NONCE` and `{"a": 5}` packs as `f459` (the opener's first packet under `NONCE`), and `join(NONCE)` returns `True` and unpacks an opener's first packet to `{"a": 6}`; HEAD opens a zero-nonce session on `start(16)` (`{"a": 5}` packs as `518d`) and the later `start(NONCE)` returns `None`.

**AC-4: The random form is unchanged**
Given `start()` and `start(None)` on fresh sessions
When called
Then each returns 16 bytes (random) and opens the session, as at HEAD.

**AC-5: A bytes-like nonce of 16 bytes still opens a session, with the same bytes**
Given `bytes(16)`, `bytearray(range(1, 17))`, `memoryview(bytes(range(1, 17)))`, `memoryview(bytes(32))[::2]`, `memoryview(array('I', range(4)))`, `memoryview(bytes(16)).cast("B", shape=[4, 4])` and a `bytes` subclass of `range(1, 17)`
When each is passed to `start` and, on another fresh `S`, to `join`
Then `start` returns the 16 bytes (`00`x16, `0102030405060708090a0b0c0d0e0f10`, `0102030405060708090a0b0c0d0e0f10`, `00`x16, `00000000010000000200000003000000`, `00`x16, `0102030405060708090a0b0c0d0e0f10`), `join` returns `True`, and the opened session packs what it packed at HEAD (`start(bytes(16))` packs `{"a": 5}` as `518d`; `start(bytes([1] * 16))` as `d9b9`).

**AC-6: A wrong length is still refused**
Given `bytes(15)`, `bytes(17)`, `b""`, `memoryview(b"")`, `memoryview(array('I', range(16)))` (64 bytes in 16 items) and `memoryview(b"\x07").cast("B", shape=[])` (a zero-dimensional view of one byte)
When each is passed to `start` and to `join`
Then `start` returns `None` and `join` returns `False`, as at HEAD.

**AC-7: A released view and a hostile `__bytes__` object are refused, not raised**
Given a `memoryview` that was `release()`d, an object whose `__bytes__` raises `RuntimeError`, and an object with a raising `__len__` and `__bytes__`
When each is passed to `start` and to `join`
Then `start` returns `None` and `join` returns `False`, `__bytes__` is never called, and nothing is raised (HEAD: `ValueError: operation forbidden on released memoryview object` and the `RuntimeError`).

**AC-8: `load`, `start` and `join` agree**
Given the inputs of the second table in Problem, each as 32 bytes for `load` and as 16 bytes for `start` and `join` (released view, plain hostile object, `bytes` subclass, 2-D view, 0-dimensional view, view with 4-byte items, strided view, read-only view, `bytearray` view)
When all three are called
Then `load` returns a session exactly when `start` and `join` open one, and `None` exactly when they refuse. A `bytes` or `bytearray` subclass whose `__bytes__` raises `RuntimeError` makes all three raise that `RuntimeError`; one whose `__bytes__` returns 3 bytes makes all three refuse; one whose `__bytes__` returns 16 other bytes opens `start` and `join` on those bytes (the returned nonce is those bytes). These three rows are today's behaviour in `load`, `start` and `join` and stay.

**AC-9: An open session, the vector and the constructor are unchanged**
Given an opened session `S.start(NONCE)`
When `start(16)`, `join(16)`, `join(NONCE)` and `start(NONCE)` are called on it
Then they return `None`, `False`, `False` and `None`, as at HEAD. And for seed `bytes(range(1, 33))` and nonce `NONCE` the position row packs to `b55d0a29c56c203712b241232e` (the C# vector, `test_ac1_ciphertext_matches_csharp`); `PackSession(32)` raises `TypeError` and `PackSession(bytes(31))` raises `ValueError` `seed must be 32 bytes, got 31`.

## Non-Functional Requirements

**Compatibility**
- No wire change. A caller that passed anything but `bytes`, `bytearray` or `memoryview` as a nonce now gets `None` (`start`) or `False` (`join`). The language-pair `session` hand-offs (`.github/workflows/drivers/handoff.py` passes `bytes`) and the position vector are unchanged.
- Differential against HEAD (what must stay byte-identical, probed on the HEAD export and the throwaway copy: 2,760 calls = 6 lengths (0, 1, 15, 16, 17, 32) x 40 random nonces x every available shape of each): for every `bytes`, `bytearray`, `memoryview` (plain, of a `bytearray`, strided, 4-byte items, 2-D) and their subclasses, at every length, `start` returned the same value, `join` returned the same value, three packets packed to the same bytes and the waiter unpacked the same rows: 1,840 of 1,840 identical. 160 calls changed, all at length 16 and all in four kinds that are not bytes-like (`list`, `tuple`, `array('B')`, ctypes array): opened before, refused now. No call that was refused or raised at HEAD opens now.

**Security**
- A nonce that is not bytes can no longer open a session keyed by a fixed, length-derived or small-integer nonce, and a mistyped call cannot leave a session open on a nonce the caller never chose.

**Reliability**
- `start` and `join` convert the value once and check, use and (for `start`) return that one copy, so a `bytearray` that another thread changes between the check and the use cannot give a nonce of another length.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | the thirteen values to `start` on fresh sessions | `None`, no exception, `pack` returns `None` | `python/tests/test_session.py` |
| AC-2 | the thirteen values and `None` to `join` | `False` (`is False`), no exception, session closed | `python/tests/test_session.py` |
| AC-3 | refused `start(16)` and `join(16)`, then the valid calls | `NONCE` returned, first packet unpacks to `{"a": 6}` | `python/tests/test_session.py` |
| AC-4 | `start()`, `start(None)` | 16 bytes, session open | `python/tests/test_session.py` |
| AC-5 | the seven shapes to `start` and `join` | the listed returns; `518d` and `d9b9` packed | `python/tests/test_session.py` |
| AC-6 | the six wrong shapes | `None` / `False` | `python/tests/test_session.py` (extends `test_ac4_bad_lengths_create_nothing`) |
| AC-7 | released view, hostile `__bytes__`, hostile `__len__` | `None` / `False`, `__bytes__` not called | `python/tests/test_session.py` |
| AC-8 | the nine shapes through `load`, `start`, `join`; three subclass-`__bytes__` rows | the three agree; the three subclass rows as listed | `python/tests/test_session.py` |
| AC-9 | open session; vector; constructor | as at HEAD | `python/tests/test_session.py` (`test_ac1_ciphertext_matches_csharp` and `test_ac5_the_constructor_keeps_its_errors` stay unchanged) |

New cases are named `test_az2244_ac<N>_...` so they do not clash with the AZ-2231 names. AC-1, AC-2, AC-3 and AC-7 must fail at HEAD first. `test_session.py` is 211 lines; about 110 new lines keep it under 500.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5, AC-9 | language-pair `session` hand-offs, Python as opener and waiter (`.github/workflows/drivers/handoff.py`: `SESSION_SEED` and `SESSION_NONCE` are `bytes`) | unchanged run | same ciphertext, 0 mismatched bytes | Compatibility |
| AC-9 | `python/tests/test_hostile_unpack.py::test_session_unpack_hostile_payload` (opens with `bytes` seed and nonce) | unchanged run | passes | Compatibility |

## Constraints

- ADR-001: Python only; no cross-package import. TypeScript, which throws for these inputs today, is not touched.
- Files at or under 500 lines (`_session.py` is 88, `test_session.py` 211).
- Error kind and label of existing errors unchanged (decision C15): `PackSession(seed)` keeps `TypeError` / `ValueError` `seed must be 32 bytes, got N`; `start` and `join` add no new error, they return `None` / `False` as they already do for a wrong length.
- No new dependency; the return types stay `bytes | None` (`start`) and `bool` (`join`); the parameter annotations stay `bytes | bytearray | memoryview` (and `| None` for `start`).
- The wire bytes of every call that opens a session today with a `bytes`, `bytearray` or `memoryview` nonce are unchanged.

## Risks & Mitigation

**Risk 1: Callers that passed another buffer object or a list of integers as the nonce**
- *Risk*: `array.array('B', ...)`, a ctypes array, a NumPy `uint8` array or a list of 16 integers opened a session before; now `start` returns `None` and `join` returns `False`.
- *Mitigation*: `bytes(...)` around the value restores it. The README Python upgrade note names it. The three accepted types are the ones the signature already declares.

**Risk 2: `None` and `False` hide a type mistake that raised before**
- *Risk*: a string, a float, a released view or `join(None)` raised and now gives `None` / `False`, which a caller may not check; `join` then leaves the session closed and the first `pack` returns `None`.
- *Mitigation*: it is the existing "bad nonce gives no session" rule (a wrong length already gave `None` / `False`), the one AZ-2231 chose for `load`; the owner chose it over raising (option B there).

**Risk 3: A subclass with its own `__bytes__`**
- *Risk*: the check accepts a `bytes` or `bytearray` subclass, and `bytes(value)` calls its `__bytes__`, which may raise or return other bytes; `start` returns the bytes it used, not the bytes the subclass holds.
- *Mitigation*: unchanged and equal in `load`, `start` and `join` (AC-8); the code is the caller's own. Reading the held bytes instead (for example through `memoryview(value).tobytes()`) is a separate decision for all three methods, not made here.

**Risk 4: The constructor still takes a list of 32 integers**
- *Risk*: `start` and `join` are strict now, the constructor `PackSession([7] * 32)` is not.
- *Mitigation*: AZ-2231 Excluded and assessment O19; one open item for the owner, not widened here.

## Owner decision (2026-10-06)

Assessment round 2 routed this as gap-clear; the quoted contract lines are the basis; no owner question. Basis: "a nonce length other than 16 opens 0 sessions" and "length other than 16 joins 0 sessions" (`pack-session.md:21-22`), and the AZ-2231 Outcome ("For anything else it returns `None`. It never raises for the type of its argument"), applied to `start` (`None`) and `join` (`False`). The ticket and the assessment text are confirmed by the probes above, with one reading made explicit: `start(None)` is not "anything else", it is the documented random-nonce form and keeps drawing.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3). `PackSession.start(nonce)` returns `None` and `join(nonce)` returns `False`, raising nothing, for anything that is not a `bytes`, `bytearray` or `memoryview` of exactly 16 bytes, and the session stays closed. `start()` and `start(None)` still draw the nonce. `python/src/packbin/_session.py` (+20/-13): one private `_exact_bytes(value, size)` (an `isinstance` check, a `ValueError` catch for a released view, one `bytes()` copy, the length counted in bytes) shared by `load`, `start` and `join`; `_open` lost its own length check. `start(16)`, a list or tuple of 16 ints, an `array.array` and a ctypes array opened a session (`start(16)` used 16 zero bytes and packed `{a: 5}` as `518d`); a `str`, a float, an `object()`, a released memoryview, an object with a raising `__bytes__` and `join(None)` raised. No wire change.

Tests (`python/tests/test_session.py`, +243 lines, 64 new tests; 28 of them fail at HEAD): AC-1 `test_az2244_ac1_start_refuses_a_nonce_that_is_not_bytes_like` (13 values); AC-2 `..._ac2_join_refuses_...` (13 values and `None`); AC-3 a refused `start` and a refused `join` leave the session closed and usable (`f459`, the waiter unpacks `{"a": 6}`); AC-4 `..._ac4_start_without_a_nonce_still_draws_one`; AC-5 a bytes-like nonce of 16 bytes opens with those bytes (seven shapes) and the packets under known nonces are unchanged (`518d`, `d9b9`); AC-6 a wrong length is refused (six shapes); AC-7 a released view and a hostile object are refused, not raised; AC-8 `load`, `start` and `join` agree on nine shapes, and for a `bytes` and a `bytearray` subclass whose `__bytes__` raises, returns another length or other bytes; AC-9 an open session refuses a second `start` or `join`. The vector and the constructor stay in the unchanged `test_ac1_ciphertext_matches_csharp` and `test_ac5_the_constructor_keeps_its_errors`. The Python suite is 485 passed (326 before; this spec +64, AZ-2245 +35, AZ-2248 +21, AZ-2249 +39).

Evidence: a differential against the HEAD export, 2,840 calls over six lengths and nine shapes (bytes, bytearray, memoryview plain, of a bytearray, strided, of 4-byte items and 2-D, subclasses, list, tuple, `array('B')`, ctypes): 2,680 identical; the 160 changed calls are all length 16 in the four non-bytes kinds (40 each) and each went from open to refused; nothing refused or raised at HEAD opens now. The driver `handoff.py` (nine pack, twelve unpack commands) and `position.py` print what a `git archive HEAD` export prints; position stays `4001000065cd1d00a3e1110100`.

Discoveries: `start` checks "session already open" before it converts and `join` converts first, so a `bytes` subclass whose `__bytes__` raises raises from `join` on an already-open session, as at HEAD (Risk 3, unchanged); a subclass whose `__bytes__` raises or returns other bytes propagates or is used in all three methods (undecidable; switching all three to `memoryview(x).tobytes()` would be a separate decision). `start(None)` is the documented random-nonce form, not "anything else". The assessment's `d2bf` is the same observation with another seed and scheme; this spec reports `518d`. The assessment's TypeScript `TypeError` was not re-probed here (AZ-2243 did). Open, owner: the constructor `PackSession([7] * 32)` still accepts a list (AZ-2231 Excluded). Not run: Python 3.10 to 3.13. Docs: README patch (Python paragraph), Python description and `tests.md`, `contracts/library/pack-session.md`.
