**Spec 3 of 4: PB-03 (self-contained, 2026-10-25).** Copy into packbin's `_docs/02_tasks/todo/` on intake. The byte definitions are PB-01's "Normative specification" (Spec 1); this task does not redefine them.

# Frame mode golden vectors

**Task**: PB-03_frame_golden_vectors
**Name**: Frame mode golden vectors
**Description**: A fixture pins seal, open, the replay window and the MAC-only call of frame mode, so every package and meshbell's radio code agree on every byte and every result.
**Complexity**: 4 points
**Dependencies**: PB-01, PB-02
**Component**: `fixtures/frame/`, `scripts/frame/`
**Tracker**: umbrella AZ-3192; packbin gives this task its own AZ id on intake
**Epic**: new packbin epic "Frame mode" (created on intake)

## Problem

Frame mode will be implemented in Rust first and in C#, Java and Swift later, and meshbell pins packbin's vectors with the packbin commit that produced them. Without one fixture that every implementation loads, two packages can agree with themselves and disagree with each other, and meshbell cannot tell a packbin change from a meshbell bug.

## Outcome

* `scripts/frame/framefmt.py`: the reference seal, open, replay window and MAC-only call, written from PB-01 only (Python 3.9 or newer, standard library plus `scripts/crypto/chacha20.py` from PB-02).
* `scripts/frame/gen_vectors.py [out]`: writes `fixtures/frame/vectors.txt` from a fixed seed (a rerun gives the same file).
* `scripts/frame/check_vectors.py [file]` and `fixtures/frame/check-vectors.sh`: re-derive every row and check the coverage list below; `check-vectors.test.sh` proves the check fails on a corrupted copy.
* `fixtures/frame/README.md`: row syntax, coverage, how a package loads the file.
* `fixtures/frame/ring-cases.txt` (optional now, needed when a second package implements frame mode): rows the cross-language ring seals in one language and opens in every other.

## Row syntax (proposal; keep it close to the ECC fixture)

One row per line, space-separated `name=value` fields, hex unless noted, `#` comments. Every row has `case` (unique name) and `op`.

| `op` | Fields in | Fields out |
| --- | --- | --- |
| `seal` | `key`, `epoch`, `dir`, `tag_len`, `msg_id`, `kind`, `ad`, `clear`, `plain` | `body` or `result` (an error kind) |
| `open` | `key`, `epoch`, optional `prev_key` and `prev_epoch`, `dir`, `tag_len`, `msg_id`, `kind`, `ad`, `clear_len`, `body`, optional `window` (`top:bits` in hex) and `counter`, `out_len` | `result` (`Ok` or an error kind), on `Ok` also `slot` (`current` or `previous`), `plain`, and `window_after` when a window was given |
| `mac` | `key`, `epoch`, `label` (hex), `n`, `message` (hex; or `parts` as `hex\|hex\|…`) | `tag` or `result` |
| `replay` | `steps` (a list `check:N` or `commit:N`) | `results` (one per `check`) |
| `keys` | `key`, `epoch`, `dir` or `label` | `k_enc` and `k_mac`, or `k_label` (pins the key schedule on its own) |

## Coverage (all required)

**Known-answer rows.** E1 to E5 of PB-01 ("Worked examples") as `keys`, `seal`, `open` and `mac` rows, reproduced byte for byte. They were computed by meshbell with an independent implementation; a mismatch means the reference or the contract text is wrong, and is resolved before any package uses the file.

**Key schedule and nonce.**

* `keys` rows for each direction 1, 2, 3 at epochs 0, 1, 7, 0xFFFF and 0xFFFFFF (the largest; salt ends `ffffff00`, nonce ends `ffffff`).
* `seal` refusals: epoch 0x1000000, direction 0 and 4, `kind` 16, a direction the session did not load: `BadValue`.

**Lengths.**

* `plain` of 0, 1, 12, 42, 63, 64, 65, 128, 192, 236 and 251 bytes (236 is meshbell's largest with no clear part; 251 + tag 4 is the 255-byte body limit).
* `clear` of 0, 3 and 40 bytes; `ad` of 0, 11 and 255 bytes.
* `seal` refusals: body of 256 bytes (`TooLong`), `ad` of 256 bytes (`TooLong`), output buffer one byte short (`BufferFull`).
* `tag_len` 4, 8 and 16 for the same inputs (the tags are prefixes of one HMAC); `tag_len` 0, 5 and 32 at load: `BadValue`.

**Tamper rows (**`open` gives `TagMismatch`, no `plain`). For E1, E2 and E3 each: one bit flipped in the first and in the last byte of `ad`, of `clear` (E3), of the ciphertext and of the tag; `msg_id` with one bit flipped (the tag binds the nonce); `kind` changed; direction changed; epoch + 1 with no previous slot; another key; `clear_len` one too large and one too small.

**Short and buffer rows.** `body` shorter than `clear_len + tag_len`: `ShortPacket`. `out_len` one byte short of the plaintext: `BufferFull` (and no `plain` written).

**Previous slot.**

* A body sealed at (key A, epoch 6) opened by a session at (key B, epoch 7) with previous (A, 6): `Ok`, `slot=previous`.
* The same body with no previous slot: `TagMismatch`.
* A body sealed at (B, 7) opened by the same two-slot session: `Ok`, `slot=current`.

**Replay window (**`replay` rows and `open` rows with a window). The sequence below, on an empty window, with these results (verified with a model of PB-01's rules):

| Step | Call | Result | State after |
| --- | --- | --- | --- |
| 1 | check 100 | `Fresh` |  |
| 2 | commit 100 |  | top 100, bits `0x1` |
| 3 | check 100 | `Duplicate` |  |
| 4 | check 99 | `Fresh` |  |
| 5 | commit 99 |  | top 100, bits `0x3` |
| 6 | check 37 | `Fresh` (100 − 37 = 63) |  |
| 7 | commit 37 |  | top 100, bits `0x8000000000000003` |
| 8 | check 36 | `TooOld` (64 behind) |  |
| 9 | check 37 | `Duplicate` |  |
| 10 | check 163 | `Fresh` |  |
| 11 | commit 163 |  | top 163, bits `0x8000000000000001` |
| 12 | check 100 | `Duplicate` (63 behind, still in the window) |  |
| 13 | check 99 | `TooOld` |  |
| 14 | check 200 | `Fresh` |  |
| 15 | commit 200 |  | top 200, bits `0x2000000001` |
| 16 | check 163 | `Duplicate` |  |
| 17 | check 100 | `TooOld` |  |

Plus: an empty window checks 0 as `Fresh`, and after commit 0 checks 0 as `Duplicate`. After commit 2^64 − 1 on an empty window: check 0 `TooOld`, check 2^64 − 64 `Fresh`, check 2^64 − 65 `TooOld` (no overflow). `open` rows: a valid body with a duplicate counter gives `Duplicate` and `window_after` equal to `window`; a tampered body with a fresh counter gives `TagMismatch` and `window_after` equal to `window` (a failed open never changes the window); a valid body with a fresh counter gives `Ok` and the counter committed.

**MAC-only.**

* E4 and E5; `label` of 1 and 32 bytes; `label` of 0 and 33 bytes: `BadValue`; `n` 4, 8, 16 and 32; `n` 0, 2 and 5: `BadValue`.
* `message` of 0, 5, 55, 56, 63, 64, 119, 120 and 255 bytes (SHA-256 padding boundaries after the 64-byte key block; 255 is meshbell's largest: a 4-byte wave and the 251 frame bytes before the MIC), each also split into two and three `parts` with the same tag.
* A tag with one bit flipped: verify is false.

## Scope

### Included

* The reference generator, the fixture, the check scripts, the README, the coverage check

### Excluded

* Package implementations (PB-04 for Rust; later tasks for the others)
* Hardware timing (later task)

## Acceptance Criteria

**AC-1: Every row reproduces**
Given `fixtures/frame/vectors.txt`
When `check_vectors.py` re-derives every row with the reference  
Then every byte and every result matches, and the coverage list above is complete

**AC-2: The contract decides every byte**
Given PB-01's contract and an implementation written independently of `framefmt.py`
When E1 to E5 and three other rows of different kinds are recomputed  
Then they match

**AC-3: The check is not vacuous**
Given copies of the file with one byte changed in a `body`, a `tag`, a `result` and a `results` list  
When `check-vectors.test.sh` runs  
Then each copy fails

**AC-4: Deterministic**
Given the generator and its seed  
When it runs twice  
Then the two files are identical

## Unit Tests

| AC Ref | What to Test | Required Outcome |
| --- | --- | --- |
| AC-1 | `check_vectors.py` over the file | all rows match, coverage complete |
| AC-2 | E1 to E5 and three rows recomputed independently | match |
| AC-3 | corrupted copies | each fails |
| AC-4 | two generator runs | identical files |

## Constraints

* Meshbell pins this file with the packbin commit that produced it; any later change to a row is a wire change and follows packbin's wire-stability policy (announced, versioned).
* Standard library only for the Python scripts, plus PB-02's `chacha20.py`.

## Risks & Mitigation

**Risk 1: The reference and the first package share a mistake**

* _Mitigation_: E1 to E5 come from meshbell's independent implementation; AC-2 asks for one more independent recomputation


