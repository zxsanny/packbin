# Security review — frame mode ports, loop 75

Scope: `88cbb2b..99b7dec`, frame mode (HKDF-SHA256 key schedule, ChaCha20, truncated HMAC-SHA256 tag, replay window, previous key, MAC-only call) in C++, Go, Python and TypeScript. Contract `pack-session.md` 3.0.0. Independent read-only agent; probes ran on copies (Python 3.13, Node 22, Go in docker, clang++ with ASan and UBSan).

## Verdict: PASS_WITH_WARNINGS

No Critical, High or Medium findings. No way was found to open a forged, altered or replayed frame, or to write output or window state on a refused call, in any port. Flipping every byte of a sealed body gave 0 accepted opens (TypeScript, Go). A differential test of 4,207 replay-window steps near 0, 63, 64 and 2^64-1 matched an independent model in all four ports. The open order, nonce, salt, length bytes, tag compare, previous-key handling and wipes match the contract in all four.

## Findings

| Id | Severity | Where | Finding | Disposition |
|----|----------|-------|---------|-------------|
| L1 | Low | Go `frame_mac.go` | a zero-value `MacKey` ran HMAC with an empty key (fail-open) | fixed in loop 75 (key must be 32 bytes) |
| L2 | Low | Python `_frame_session.py` | a negative counter with a window raised `ValueError`, not `BadValue` | fixed in loop 75 |
| L3 | Low | TypeScript `frame-session.ts` | direction masks of 2^32 and above wrapped (ToInt32) | fixed in loop 75 |
| L4 | Low | TypeScript | `open(window = null)` and sparse `parts` threw | fixed in loop 75 |
| L5 | Low | C++ `frame.cpp` | `open` reads `body` twice (tag, then decrypt), no snapshot; an ISR-written ring could change between | documented hard requirement (`frame.hpp`, README); copy costs about 255 B of stack: owner decision |
| I1 | Info | all | Duplicate/TooOld before the MAC lets a sender learn window state for a counter it supplies | follows the normative order; the counter must come from authenticated bytes (documented) |
| I2 | Info | C++, Python, TypeScript | default `counter` 0 with a window makes later frames Duplicate | fails closed |
| I3 | Info | TypeScript | `MsgContext.kind` read twice (a getter could flip) | fixed in loop 75 |
| I4 | Info | Python | `MacKey.__init__` internal and accepts any bytearray; `config.directions` accepts 3.0 and True | MacKey guarded in loop 75 |
| I5 | Info | C++ | `seal` overlap of `ad` with `out` gives a silently wrong tag (documented) | documented |
| I6 | Info | C++, Python, TypeScript | a `close` racing an `open` could accept a frame under the zero key | the stated concurrency rule; Go takes a lock |

Also: the README examples in C++, Python and TypeScript use an all-zero key with the comment "use a random key from your key store" (documentation copy-paste risk only). Wipes are best effort and disclosed in each port.

16-bit `size_t` on AVR: read, not run. Every size sum was checked by hand (largest 255 + 255 + 16).
