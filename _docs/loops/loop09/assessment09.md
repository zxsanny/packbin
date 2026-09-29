# Feature assessment — loop 9

loop: 9
feature: pack-session
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-09-29
**Implement pass**: batches 01–04, `_docs/03_implementation/batch_01_loop9_report.md` through `batch_04_loop9_report.md`
**Verdict**: COMPLETE — 10 covered / 7 out-of-scope / 0 gap-clear / 0 gap-unclear

Intent is `_docs/02_task_plans/pack-session/problem.md`, `acceptance_criteria.md`, and `scenarios.md`. The three discovery rows are `clear` and match the built session.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Opener sends 16 bytes, waiter joins, one position row | covered | AC-2; `SessionTests.Ac2_OpenerPackWaiterUnpack`; `PackSession.Pack` / `Unpack` | spec |
| S2 | Clear pack stays the golden hex | covered | AC-1; `SessionTests.Ac1_ClearPackUnchanged`; `BinaryPacker.Pack` | spec |
| S3 | A second packet on the same connection | covered | AC-4; `SessionTests.Ac4_SecondPacket`; per-direction packet counter in `PackSession` | spec |
| S4 | Two clients, one seed, two 16-byte values | covered | AC-5; `SessionTests.Ac5_TwoSessionsStayApart`; HKDF salt is the nonce | spec |
| S5 | Pack before start or join | covered | AC-7; `SessionTests.Ac7_PackBeforeOpenProducesNothing`; `Pack` returns null when send key is unset | spec |
| S6 | Bad seed or join length | covered | AC-6; `SessionTests.Ac6_BadLengthsCreateNothing`; `Load` / `Join` reject other lengths | spec |
| S7 | A row packed before this feature still unpacks | covered | S7; `SessionTests.S7_ClearUnpackStillReturnsTheRow`; `BinaryPacker.Read` | spec |
| S8 | The waiter packs and the opener unpacks | covered | AC-3; `SessionTests.Ac3_WaiterPackOpenerUnpack`; swapped HKDF halves | spec |
| S9 | Six languages, one ciphertext, a peer unpacks | covered | AZ-2025 AC-1 and AC-2; `language-pair.sh` session ring; each language's `PackSession` | spec |
| S10 | README shows clear pack and one session | covered | AZ-2026 AC-1 and AC-2; `README.md` session example names load, start, join, pack, unpack | spec |
| D1 | The pad is HKDF-SHA256 then ChaCha20, packet counter as the 12-byte nonce | covered | Contract `## Construction`; RFC block test in `SessionTests.ChaCha20MatchesRfc8439Block`; `SessionPad.Xor` | batch_01 discoveries |
| O1 | A flipped bit is not detected | out-of-scope | acceptance criteria `## Out of scope`: "A check that detects a flipped bit" | spec |
| O2 | A clock-based seed | out-of-scope | acceptance criteria `## Out of scope`: "A clock-based seed" | spec |
| O3 | The library stores the seed | out-of-scope | acceptance criteria `## Out of scope`: "Storing the seed inside the library" | spec |
| O4 | The library opens the socket | out-of-scope | acceptance criteria `## Out of scope`: "Opening the socket" | spec |
| O5 | Archangel wiring | out-of-scope | acceptance criteria `## Out of scope`: "Wiring the Archangel server or the Vue client" | spec |
| O6 | Permission checks | out-of-scope | `scenarios.md`: "Not walked: permission checks, undo, and a clock. The library has no login" | spec |
| O7 | Undo | out-of-scope | `scenarios.md`: "Not walked: permission checks, undo, and a clock" | spec |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

## Not walked

The host `cpp/build` binary and the handoff hex that omitted a type byte are tooling. They are not a second session behavior.
