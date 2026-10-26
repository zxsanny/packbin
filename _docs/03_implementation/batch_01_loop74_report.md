# Batch Report

**Batch**: 1
**Tasks**: AZ-3280_ring_ci_stream_removal, AZ-3281_csharp_stream_removal, AZ-3282_java_stream_removal, AZ-3283_python_stream_removal_crypto
**Date**: 2026-10-26

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3280_ring_ci_stream_removal | Done | 3 deleted, 19 edited (`.github/workflows/`, 8 drivers, `scripts/loop-tests.sh`) | wiring tests, run-suite self-tests, 10 readers: exit 0; ring in an isolated tree: language pairs passed (66 s), ECC ring 64 pairs, 45,440 rows, 0 mismatched | None |
| AZ-3281_csharp_stream_removal | Done | 4 deleted, 12 edited (`csharp/`, `fixtures/hostile/fuzz/csharp/`) | 4,287 / 4,287 (HEAD 4,319; -32 session tests), netstandard2.0 4,287 / 4,287, 0 warnings | None |
| AZ-3282_java_stream_removal | Done | 3 deleted, 12 edited (`java/`, `fixtures/hostile/fuzz/java/`) | `java/test.sh` exit 0, 9,725 checks (HEAD 9,815; -90), api-check PASS | None |
| AZ-3283_python_stream_removal_crypto | Done | 4 deleted, 1 moved (`_session_pad.py` to `_crypto.py`), 1 renamed test, 1 new test, 11 edited (`python/`, `fixtures/hostile/fuzz/python/`) | 3,793 passed, 0 failed (HEAD 3,877) | None |

Parallel wave of four workers with disjoint write sets; the parent joined, checked the union and ran the ring on the joined tree.

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop; the loop plan runs one independent read-only security review of the whole diff (step 14).

## AC evidence

| Task / AC | Evidence |
|-----------|----------|
| AZ-3280 AC-1 | `language-pair.sh` keeps the clear, short-packet and position stages (340 handoff lines to 276); every driver exits 2 on the four session commands; `git grep -E 'pack-session\|unpack-session\|session_hex\|session_ecc_hex\|SessionTests\|nostd_session' -- .github scripts`: 0 hits; ring on the joined tree: see Union check |
| AZ-3280 AC-2 | `ring-wiring-rows.test.sh` exit 0 (23 checks, 102 Go-line mutants), `ring-wiring-swift.test.sh` exit 0 (62 checks, 122 Swift-line mutants); temp-copy mutants (`handoff go csharp user`, `handoff swift csharp user` dropped): exit 1 naming the line, 1 of 1 each |
| AZ-3280 AC-3 | `run-suite.test.sh` exit 0 "all checks passed" (sources `run-suite-swift.test.sh`); cargo lines 15 to 13, timed Rust steps 13 to 11; `--features frame,ecc --lib frame_` 12 passed |
| AZ-3281 AC-1 | `git grep -E 'PackSession\|SessionPrivates\|OpenPair' -- csharp fixtures/hostile/fuzz/csharp`: 0 hits |
| AZ-3281 AC-2 | `FrameVectorTests.Ac1_EveryRowOfTheFrameFixtureMatches` (157 rows), `CryptoVectorTests.Ac2_EveryPrimitiveRowMatches` (27 rows) pass |
| AZ-3281 AC-3 | `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`: 4,287 passed, 0 failed, both target frameworks |
| AZ-3282 AC-1 | `javap -public` over `java/out/main` (341 lines): 0 hits for seed, `PackSession`, `start(`, `join(`, `SEED_SIZE`, `NONCE_SIZE` (see Discovered 2) |
| AZ-3282 AC-2 | scratch harness calling `FrameVectorsTest.check` and `CryptoVectorsTest.check`: 157 rows, 0 mismatches; 27 rows, 0 mismatches (HEAD and after) |
| AZ-3282 AC-3 | `java/test.sh` exit 0, 12 s, 9,725 checks |
| AZ-3283 AC-1 | `test_star_import.py` (7 tests): no stream name in `dir`, `__all__` or the star import; `_session`, `_session_pad` not importable; `_crypto` not exported |
| AZ-3283 AC-2 | `tests/test_crypto_vectors.py` 41 cases: 27 of 27 rows (SHA-256 6, HMAC 8, HKDF 3, ChaCha20 block 6, XOR 4), 6 in-suite mutant copies each failing on exactly the changed row, 7 guard cases; one-off code mutant (rotation 8 to 7): the 10 ChaCha rows fail |
| AZ-3283 AC-3 | pytest `-v --tb=short` on Python 3.14: 3,793 passed, 0 failed, 0 skipped; `pyproject.toml` `dependencies = []` |

## Mixed-file test counts (before / after)

| File | Before | After |
|------|--------|-------|
| C# `EccSessionTextTests` | 14 | 7 (EC-10 out, EC-11 kept) |
| C# `EccDispatchOrderTests` | 11 | 5 |
| C# `TopRangeAndSessionTests` | 16 | 14 |
| C# `WrittenWhenTests` | 10 | 9 |
| Java `EccSchemeTest` (tests / checks) | 14 / 41 | 7 / 20 |
| Java `EccDispatchOrderTest` | 8 runs / 32 | 6 runs / 10 |
| Java `MissingNestedValueTest` | 10 / 72 | 9 / 68 |
| Java `PackStrictTest` | 11 / 139 | 10 / 130 |
| Java `TimesLongerTest` | 7 / 27 | 6 / 23 |
| Python `test_ecc_session_text_dispatch.py` to `test_ecc_text_dispatch.py` | 79 | 71 |
| Python `test_ecc_dispatch_order.py` | 6 | 4 |
| Python `test_hostile_unpack.py` | 16 | 16 (one plain-unpack test moved in) |
| Python `test_star_import.py` | 5 | 7 |

## Union check (parent)

- `git grep -n PackSession -- csharp java python .github scripts fixtures/hostile/fuzz/{csharp,java,python}`: one hit, `python/tests/test_star_import.py:14` (the name list the AC-1 test checks for absence).
- Ring on the joined tree (`scripts/loop-tests.sh --only ring`): `STAGE ring: PASS (69s)`, language pairs passed, `ring-ecc: 64 pairs, 45440 rows, mismatched rows: 0` (load 5 to 9). CI-parity: PASS (each package suite as CI runs it, by the workers; the ring stage here)

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Clarity |
|---|----------|---------|-------------------|---------|
| 1 | AZ-3281, AZ-3282, AZ-3283 AC-3 | Each package had one "duplicate type before parity mix" check (AZ-2704 AC-3) whose parity-mix half ran through a session | moved to the clear unpack call with the same handlers; the order is still checked | clear |
| 2 | AZ-3282 AC-1 | `java/api-check.sh` is the Android API 26 check, not a public-API list | AC-1 checked with `javap -public`; spec wording to correct | clear |
| 3 | AZ-3280 | `drivers/handoff-go/go.mod` keeps `x/crypto` and `x/sys`: they come in through `packbin/go`, which keeps `x/crypto/chacha20` under D2 | unchanged; inventory corrected | clear |
| 4 | AZ-3280 | Until AZ-3284 and AZ-3285 land, the Rust `nostd_session_tests` no longer run and the Swift session suites run without the thread sanitizer | accepted for the batch order | clear |
| 5 | AZ-3280 | `publish-npm.test.sh` has no session wording (`@noble/hashes` stays under D2) | left unchanged | clear |
| 6 | AZ-3283 | The Python crypto now refuses a ChaCha20 stream past the last block counter (the old pad wrapped silently, repeating keystream), takes the HKDF `info` (RFC 5869) and checks key, nonce, counter and length | kept, tested (7 guard cases) | clear |
| 7 | AZ-3281, AZ-3283 | Test names still say "Session" (`TopRangeAndSessionTests`, `EccSessionTextTests`, `fuzz_ecc_session.py`) | left: a rename changes test ids and README references; candidate for the docs task | unclear |
| 8 | fixtures (HEAD) | The C# and Java `edges` probes print "FAIL dict: NFC and NFD forms of é are two keys" at HEAD, probably against the loop 42 ascending dict-key rule | pre-existing, not this loop; leftover candidate | unclear |
| 9 | fixtures (HEAD) | `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` also compiles `ns20/Program.cs`, whose top-level statements become the entry point | pre-existing; fix is `<Compile Remove="ns20/**" />`; leftover candidate | clear |
| 10 | fixtures | The seeded `fuzz-ecc` probes (C#, Java) draw differently once the session step is gone, so seed 41 figures no longer match the loop 41 record | noted; figures are per run | clear |

## README hunks for AZ-3291 (parent)

- C#: l.31 intro, l.880 ECC row (`PackSession.Unpack(...)`), l.1061-1089 "Encrypted session / C#", about l.1172-1210 the WebSocket C# server.
- Java: l.882 ECC row (`PackSession.unpackRepair`), l.2168 the "A session packs from several threads safely in C# and Java" bullet.
- Python: l.878 ECC row (`PackSession.unpack(..., limit=t)`), l.2029 history paragraph.
