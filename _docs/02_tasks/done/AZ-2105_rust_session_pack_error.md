# Rust `PackSession::pack` returns the pack error

**Task**: AZ-2105_rust_session_pack_error
**Name**: Rust session pack error
**Description**: `PackSession::pack` tells the caller whether the session was not open or the row could not be packed, instead of returning `None` for both.
**Complexity**: 1 point
**Dependencies**: None
**Component**: rust
**Tracker**: AZ-2105
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C30 (Rust part); discovery `scan_rust_cpp.md` S25, C9; probe R-P9.

- `PackSession::pack` (`rust/src/session/mod.rs:63-69`) is:

  ```
  let send = self.send.as_ref()?;
  let mut clear = BinaryPacker::pack(scheme, row).ok()?;
  ```

  `.ok()?` throws away the `PackError`:
  - `Missing(name)`;
  - `Type(name)`, e.g. a string over 65 535 bytes, a `bytes(n)` of the wrong length, or a packed list whose length differs from its count.

  The caller gets the same `None` as "pack before start or join".
- **R-P9:**
  - scheme: one `BoundField::utf8(0, …)`;
  - session: `PackSession::load(&[7; 32])` then `start_with(&[1; 16])`;
  - row: a 70 000-byte string;
  - `pack` → `None`. The session is open; the real cause, `PackError::Type("0")` from `BinaryPacker::pack`, is invisible.
- The send counter already advances only on success (`mod.rs:66-67`). Keep that.
- **Cross-language:**
  - C++ returns the pack `Result` (`cpp/include/packbin/session.hpp:49-61`): `BadValue` before open; otherwise the clear-pack error with offset and field id;
  - C# / TypeScript / Python raise or return the clear-pack error.
  - The contract (`_docs/02_document/contracts/library/pack-session.md`) says pack before start or join "produces 0 payloads". It does not say the pack error is hidden.
- **Callers that must follow the change:**
  - `rust/tests/session_tests.rs:116, 128, 167`;
  - `.github/workflows/drivers/handoff-rust/src/main.rs:235` (`let Some(payload) = opener.pack(…) else { return 1; }`).

  The README has no Rust session example.

## Outcome

- A caller can tell "not open" from "this row cannot be packed", and sees the same `PackError` clear pack would return.
- Session bytes, counters and the cross-language session vectors are unchanged.

## Scope

### Included
- `PackSession::pack` returns a result whose error is either "session not open" or the clear-pack `PackError` (unchanged variants).
- Update the session tests and the Rust handoff driver to the new return type.
- Rust component doc row for `pack` (`_docs/02_document/components/04_rust_package/description.md`, PackSession table).

### Excluded
- `PackSession::unpack` before open still returns `UnpackError::Short { field: "", needed: 1, left: 0 }` (`mod.rs:76-85`); its label belongs to C15. The `/dev/urandom` source and Windows (deferred, no AC). `load`/`start`/`join` return types.

## Acceptance Criteria

**AC-1: Not open**
Given a loaded session with no `start` or `join`
When `pack` is called with the position row
Then it returns the "not open" error, 0 payloads, and the send counter stays 0 (pack-session AC-7).

**AC-2: Pack error passes through**
Given an open session (seed `07`×32, nonce `01`×16) and a row whose `utf8` field is 70 000 bytes
When `pack` is called
Then it returns the same `PackError` that `BinaryPacker::pack` returns for that row, and the send counter does not advance.

**AC-3: Next pack uses the unconsumed counter**
Given AC-2 followed by a pack of the valid position row
When the waiter unpacks the payload
Then it gets the five fields (field mismatches 0). The failed pack consumed no pad position.

**AC-4: Vectors unchanged**
Given the pack-session cross-language vectors (opener ciphertext for the golden row)
When packed through the session
Then the payload bytes are unchanged (`ac1_opener_ciphertext_matches`), and the language-pair `pack-session` / `unpack-session` cases pass.

## Non-Functional Requirements

**Compatibility**
- Payload bytes and counter semantics are unchanged. Only the return type of `pack` changes.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `ac4_bad_lengths_create_nothing` final assert, rewritten for the result type | "not open" error |
| AC-2 | R-P9 oversize string on an open session | `PackError::Type` for field `0` (today: `None`) |
| AC-3 | failed pack, then valid pack, waiter unpack | row equal, counter not skipped |
| AC-4 | `ac1_opener_ciphertext_matches`, `ac2_waiter_recovers_row`, `ac3_clear_pack_unchanged` | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | language-pair `pack-session` (Rust opener → other waiters) and `unpack-session` | handoff driver | 0 mismatched bytes; driver exit 0 | pack-session AC-2…AC-5 |
| AC-1 | driver run with no `start_with` (negative case, if the pair script has one) | exit code | non-zero, no payload printed | pack-session AC-7 |

## Constraints

- ADR-001: no shared session code; contract unchanged.
- No change to HKDF, ChaCha20, counters or wire length (pack-session restrictions).
- No new dependency (the crate has none).

## Risks & Mitigation

**Risk 1: Downstream compile break**
- *Risk*: callers matching on `Option` stop compiling.
- *Mitigation*: the only in-repo callers are the tests and the handoff driver (updated here). Note the change in the README Rust section / changelog for `v0.2.0`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Public API change: `PackSession::pack` return type `Option<Vec<u8>>` → a `Result` with a "not open" error and the `PackError` | plan row 36 (C30) | accepted-risk | Medium |
| Name and shape of the session error type should follow the error-kind decision (C15); if C15 lands first, reuse its naming | user (C15) | open | Low |

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 1). `PackSession::pack` returns `Result<Vec<u8>, SessionPackError>` (`NotOpen`, `Pack(PackError)`), source-breaking for callers that matched `Option`. The Rust handoff driver `.github/workflows/drivers/handoff-rust/src/main.rs` was changed to `let Ok(payload) = ...` in the same commit.
