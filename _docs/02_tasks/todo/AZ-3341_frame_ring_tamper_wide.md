---
loop: 77
branch: dev
ticket: AZ-3341
points: 3
---

# Frame ring: tamper rows and wider value coverage

**Task**: AZ-3341_frame_ring_tamper_wide
**Name**: Frame ring tamper rows and wider values
**Description**: The frame ring also sends tampered input and a wider range of valid input, so a permissive `open` or `verify` in any of the 8 packages turns the ring red.
**Complexity**: 3 points
**Dependencies**: AZ-3338_frame_ring
**Component**: CI ring (`.github/workflows`, `scripts/frame`, `fixtures/frame`) and the Swift error doc comment
**Tracker**: AZ-3341
**Epic**: none (AZ-3338 has none)

## Problem

The ring of AZ-3338 sends only well-formed messages: 8 seal rows and 4 MAC rows, bodies up to 46 bytes, epochs below 256, kinds 3 to 6, 11 bytes of associated data. An `open` that skips the tag check, or a `verify` that always says valid, passes all 128 comparisons, although plan decision D4 of AZ-3338 promised tamper cases. Bugs at the 64-byte cipher block edges, in the 3-byte little-endian epoch and in the 4-bit kind are invisible to it. Assessment round 1 of loop 77 (`_docs/loops/loop77/assessment77.md`, rows G1, G4 to G9) found this.

## Outcome

- Every language must refuse the same tampered messages with the same error name, and call the same wrong tags `invalid`.
- The ring covers the largest body, the block edges, the multi-byte epoch, all kinds and the empty and largest associated data.
- A driver that is too permissive makes `ring-frame.test.sh` fail.

## Scope

### Included
- New rows in `fixtures/frame/ring-cases.txt`: `open` rows (a body with one byte changed, and a body too short for its clear part and tag) with the expected error name, `verify` rows (a tag with one byte changed) with `invalid`, and wider `seal` and `mac` rows. The loader derives every expected value with `scripts/frame/framefmt.py`, as it does for the existing rows.
- `scripts/frame/ring_frame.py`: reads the two new row kinds, sends them to every reader after the writers' own lines, compares the answers with the expected names, and prints one line per reader for them.
- Driver fixes found by the first real run (error names that differ, a buffer that is too small).
- TypeScript `handoff-frame.ts` prints `ShortPacket` (its short-packet value has `field`, not `kind`).
- `ring-frame.test.sh`: a driver whose `open` accepts a tampered body fails the ring, and so does one whose `verify` always says valid.
- Swift `PackbinError.Kind` doc comment: names the frame-mode raw values and says the shared fixture spells the same kinds in Pascal case.

### Excluded
- Refusal rows (`TooLong`, `BadValue`, `BufferFull`, a direction that is not loaded): they need `dirs` and `out_len` columns in the rows and drivers that stop aborting on a bad direction. `fixtures/frame/vectors.txt` already holds 64 of them, read by the tests of all 8 packages. Left as a leftover.
- A key or msg_id of the wrong length (owner, 2026-10-27, option A): Rust takes `&[u8; 32]` and Rust and C++ take an 8-byte msg_id, so the package cannot receive it; the other six keep it in their own tests.
- MAC messages in several parts (needs a new driver line format), replay window, key rotation (out of scope of AZ-3338).

## Acceptance Criteria

**AC-1: Tampered bodies are refused alike**
Given sealed bodies of E1, E3 and clear3 with one byte changed in the clear part, in the ciphertext and in the tag, and a body shorter than clear_len + tag
When each of the 8 languages opens them
Then every language prints `TagMismatch` (`ShortPacket` for the short body), and the ring fails when one language prints anything else.

**AC-2: Wrong MAC tags are invalid**
Given the tags of E4 and n16 with the first byte, and with the last byte, changed
When each of the 8 languages verifies them
Then every language prints `invalid`.

**AC-3: Body sizes up to the limit**
Given seal rows with 63, 64, 65, 128, 192 and 251 plaintext bytes (the last gives a body of exactly 255 bytes with a 4-byte tag)
When each language seals and each language opens
Then all bodies equal the reference and all plaintexts come back.

**AC-4: Multi-byte epochs**
Given seal and MAC rows with epochs 0, 65535 and 16777215
When each language runs them
Then all outputs equal the reference.

**AC-5: Kinds and message ids**
Given seal rows with kinds 0, 8 and 15 and message ids of all 00 and all ff bytes
When each language runs them
Then all outputs equal the reference.

**AC-6: Associated data and clear part sizes**
Given seal rows with empty associated data, with 255 bytes of it, and with a clear part of 40 bytes
When each language runs them
Then all outputs equal the reference.

**AC-7: MAC variants**
Given MAC rows with n = 32, labels of 1 and 32 bytes, an empty message, and messages of 63, 64 and 65 bytes
When each language computes and verifies them
Then all tags equal the reference and verify to `valid`.

**AC-8: The self-test catches a permissive driver**
Given a stand-in driver whose `open` returns a plaintext for a tampered body, and one whose `verify` always says `valid`
When `ring-frame.test.sh` runs the ring with each
Then the ring exits 1 and names the row.

**AC-9: TypeScript short packet**
Given the short-body row of AC-1
When the TypeScript driver opens it
Then it prints `ShortPacket`.

**AC-10: Swift error comment**
Given `swift/Sources/Packbin/PackbinError.swift`
When a reader looks at the `Kind` doc comment
Then it names the seven frame-mode raw values (`short_packet`, `bad_value` and `too_long`, which pack and unpack share, and the frame-only `buffer_full`, `tag_mismatch`, `duplicate`, `too_old`) and says `fixtures/frame/` spells them in Pascal case.

**AC-11: The ring still passes for real**
Given the real drivers of all 8 languages
When `ring-frame.sh` runs on the Mac and in the CI `ring` job
Then it prints `64 pairs, mismatched: 0` and exits 0.

Inherited project ACs exercised: AZ-3338 AC-1, AC-4, AC-5, AC-8.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | the loader derives each new `open` and `verify` row with `framefmt.py` | a row the reference does not confirm stops the run (`ring-frame.test.sh` corrupted-row cases for the new kinds) |
| AC-8 | `ring-frame.test.sh` scenarios `open-permissive` and `verify-permissive` | exit 1, output names the row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-7, AC-9, AC-11 | the 8 real drivers, built as the CI `ring` job builds them | `bash .github/workflows/ring-frame.sh` | `64 pairs, mismatched: 0`, exit 0 | none |
| AC-10 | the Swift sources | read the comment | the six names and the Pascal case note | none |

## Constraints

- Rows keep the style of the file: explicit hex, validated by the reference on load; no second source of truth.
- A driver reports the package's own answer; it never decides a refusal itself (`meta-rule.mdc`, Real Results).
- The checker line `ring-frame: 64 pairs, mismatched: 0` keeps its shape (the self-test and CI read it).

## Risks & Mitigation

**Risk 1: Error names differ between drivers.**
The ring never printed an error name before; the TypeScript driver already prints `error` for a short packet.
- *Mitigation*: run the real ring before the first push; fix each driver in its own file.

**Risk 2: A wide row exceeds a driver buffer.**
Drivers use 300-byte output buffers; a 255-byte body fits.
- *Mitigation*: the real run shows it; no row is skipped.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Refusal rows (G2, G3) are not in the ring | owner 2026-10-27: recommended scope, per-package vectors cover them | accepted-risk | Low |
| Key and msg_id length refusals cannot reach Rust or C++ | owner 2026-10-27: option A, leave out | resolved | Low |
