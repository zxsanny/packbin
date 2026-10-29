# Scenarios — ring-key-id-length-refusals

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred. Complexity 3 points, so at most 8 rows.

## Fit (Part A)

| component / flow | today | after | who depends on today | collision |
|---|---|---|---|---|
| Ring loader (`scripts/frame/ring_frame.py`) | writes a key and a `msg_id` as bare hex; an empty value drops a field from the driver line | writes `-` for an empty value, as for `ad`, `clear` and `plain` | the 8 drivers' tokenizers; the stand-in driver of `ring-frame.test.sh` | none |
| Rust driver (`handoff-rust/src/frame.rs`) | a key that is not 32 bytes or an id longer than 8 ends the driver (exit 1, no answer); a shorter id is zero-padded and sealed | prints `BadValue` for all of them | the ring checker; `ring-frame-drivers.test.sh` (pins no length message: grep found none) | none |
| C++ driver (`handoff.cpp`) | pads or cuts the id to 8 bytes: seal returns a body, open returns `TagMismatch` | prints `BadValue` | the ring checker; the driver test | none |
| Row file and README | 43 refusal rows per language; README names Rust directions 0 and 4 as driver-answered | 58 rows; README names Rust key and id and C++ id as driver-answered too | `ring-frame.test.sh` counts rows from the output (no fixed 43); smoke scripts of earlier loops pin 43 but are not re-run | none |

No problem card.

## Matrix (Part B)

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | ring run, `seal` row with a key of 31 bytes | confirmed | all 8 drivers print `BadValue` | AC-1, AC-2, AC-3 | intake |
| S2 | ring run, `open` and `mac` rows with a key of 33 bytes | confirmed | all 8 print `BadValue` | AC-1, AC-2, AC-3 | intake |
| S3 | `seal` row with a `msg_id` of 7 bytes (short) | confirmed | all 8 print `BadValue`; no zero padding in Rust, no padding in C++ | AC-1, AC-3, AC-4 | intake |
| S4 | `open` row with a `msg_id` of 9 bytes (long) | confirmed | all 8 print `BadValue`; C++ no longer cuts it to 8 and answers `TagMismatch` | AC-1, AC-4 | intake |
| S5 | key or `msg_id` empty (`-`) | confirmed | the loader writes the token `-`; all 8 print `BadValue` | AC-1, AC-5 | intake |
| S6 | the 64 pairs of good rows (32-byte key, 8-byte id) | confirmed | unchanged, equal to the reference | AC-2 | intake |
| S7 | a driver that pads or cuts the id is put back | confirmed | the ring is red and names the row (`R.seal.id7`) | AC-6 | intake |
| S8 | `verify` row with a key of the wrong length | out-of-scope | a `verify` row answers `valid` or `invalid`, so it cannot expect `BadValue`; the Rust `verify` shares the helper of AC-3 and the driver test covers it | AC-3 | intake |

## Fit decisions

None (no problem card).

## Not walked

- A row that combines a wrong-length key or id with a second refusal (key of 31 bytes and a body of 256 bytes): which error comes first in each driver. No such row exists; the reference orders its checks, but nothing pins the 8 drivers to that order.
- A `prev_key` of the wrong length: the ring row format has no such field.
