# Python session: check the type byte before removing the pad of the whole payload (F58)

**Task**: AZ-2724_python_session_pad_f58
**Name**: Python session pad after the type check
**Description**: The Python session removes the pad of the first byte, checks the type, and only then the rest.
**Complexity**: 2 points
**Dependencies**: None
**Component**: python package (session)
**Tracker**: AZ-2724
**Epic**: AZ-2645

## Problem

`PackSession.unpack` runs the pure-Python ChaCha20 pad over the whole payload (about 93 us per 64-byte block) before it reads the type byte: random bytes cost 1.3 s per MiB with n = 0 (TypeScript 16.5 ms); with parity the 254-byte limit bounds it (security report F58).

## Outcome

- The session removes the pad of the first byte (one block), checks it against the handlers, and removes the rest only for a known type. Errors and results are the same as before (`TypeMismatch` with the clear type byte, `ShortPacket` for an empty payload).
- The contract (`pack-session.md`) and the README say that a caller bounds the payload length it hands to the Python session (the pad is linear in it).

## Acceptance Criteria

**AC-1**: A payload of an unknown type computes one pad block, whatever its length (a test counts `_block` calls).
**AC-2**: A payload of a known type computes ceil(len / 64) blocks plus at most one, and gives the same row as before (existing session tests, ring and golden unchanged).
**AC-3**: `TypeMismatch` carries the same `actual` byte as before.
