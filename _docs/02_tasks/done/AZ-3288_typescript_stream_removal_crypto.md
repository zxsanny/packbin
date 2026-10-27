---
loop: 74
branch: dev
---

# TypeScript without the stream session; crypto kept and verified

**Task**: AZ-3288_typescript_stream_removal_crypto
**Name**: Remove `PackSession` from the TypeScript package; keep its ChaCha20 and the `@noble/hashes` HKDF behind an internal module on the 27 crypto rows
**Description**: TypeScript has no stream session; its crypto is ready for the frame port.
**Complexity**: 3 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 02_typescript_package
**Tracker**: AZ-3288
**Epic**: AZ-3199

## Problem

`class PackSession` in `typescript/src/index.ts` is the stream session (ADR-009). `src/session-pad.ts` (ChaCha20) and the `@noble/hashes` import (HKDF, SHA-256) exist only for it; the frame port (loop 75) needs them (D2), and none is checked against `fixtures/crypto/vectors.txt`.

## Outcome

- 0 exported stream-session names; an internal crypto module, not exported from the package entry, passes 27 of 27 crypto rows; `@noble/hashes` stays the only runtime dependency.

## Scope

### Included
- `src/index.ts`: `PackSession`, `SESSION_INFO`, the random source and the imports only it uses.
- `src/session-pad.ts` becomes the internal crypto module (SHA-256, HMAC-SHA256 and HKDF-SHA256 through `@noble/hashes`; ChaCha20 block and XOR); a test reads all 27 rows of `fixtures/crypto/vectors.txt`.
- Delete `tests/session.test.ts`, `tests/session-payload-type.test.ts`; mixed tests keep their non-session halves: `ecc-scheme.test.ts`, `ecc-dispatch-order.test.ts`, `int-range.test.ts`, `hostile.test.ts`, `support/hostile-cases.ts`, `support/hostile-worker.ts`.
- `package.json` `exports` unchanged; `package-lock.json` regenerated only if the dependency set changes.
- `fixtures/hostile/fuzz/typescript/`: session parts out.

### Excluded
- Frame mode itself (AZ-3295, loop 75); README (AZ-3291); the TypeScript ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the built package entry
When its exports are listed and `git grep -n PackSession typescript fixtures/hostile/fuzz/typescript` runs
Then 0 session exports and 0 hits

**AC-2: Crypto verified**
Given `fixtures/crypto/vectors.txt`
When the new test runs
Then 27 of 27 rows pass, and a row with one changed hex digit fails (1 of 1 mutant caught)

**AC-3: Suite green, dependencies**
Given `npm test` and the type check
When they run
Then 0 failures and 0 type errors, and `dependencies` lists only `@noble/hashes`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | exports listing, the grep | 0 exports, 0 hits |
| AC-2 | crypto vector test plus mutant | 27/27; mutant caught |
| AC-3 | `npm test`, type check | 0 failures |

## Constraints

- A wall-clock assertion uses `tests/support/timing.ts` (`AGENT_GOTCHAS.md`, loop 43).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The crypto module has no caller until the frame port | owner D2 | accepted-risk | Low |
