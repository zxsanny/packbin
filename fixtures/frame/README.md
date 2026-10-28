# Frame mode vectors

`vectors.txt` pins frame mode of `_docs/02_document/contracts/library/pack-session.md` 2.0.0 (AZ-3202): seal, open, the replay window, the key schedule and the MAC-only call. Every package that implements frame mode loads this one file; meshbell pins it with the packbin commit that produced it. A changed row is a wire change (announced, versioned).

The reference is `scripts/frame/framefmt.py` (Python 3.9+, standard library and `scripts/crypto/chacha20.py`), written from the contract only. `scripts/frame/gen_vectors.py [out]` writes the file from a fixed seed (a rerun gives the same bytes). E1 to E5 are the worked examples of the contract, computed by meshbell with an independent implementation; `check_vectors.py` pins them as known answers.

## Row syntax

One row per line, space-separated `name=value`, `#` comments. Every row has `op` and a unique `case`. Hex has no separators and `-` is empty. Integers (`epoch`, `dir`, `tag_len`, `kind`, `n`, `clear_len`, `out_len`, `counter`) are decimal. `dirs` (default `123`) names the directions the session loaded; `out_len` is the caller's output buffer.

| op | input fields | output fields |
| --- | --- | --- |
| `keys` | `key`, `epoch`, and `dir` or `label` | `k_enc` and `k_mac`, or `k_label` |
| `seal` | `key`, `epoch`, `dir`, `tag_len`, `msg_id`, `kind`, `ad`, `clear`, `plain`, optional `dirs`, `out_len` | `body`, or `result` (an error kind) |
| `open` | `key`, `epoch`, optional `prev_key` and `prev_epoch`, `dir`, `tag_len`, `msg_id`, `kind`, `ad`, `clear_len`, `body`, optional `dirs`, `window` (`top:bits` in hex) and `counter`, `out_len` | `result` (`Ok` or an error kind); on `Ok` also `slot` (`current` or `previous`) and `plain`; with a window `window_after` (equal to `window` when the result is not `Ok`) |
| `mac` | `key`, `epoch`, `label`, `n`, and `message` or `parts` (pieces joined by a vertical bar); or `verify=<tag>` instead of `n` | `tag`, or `result`; `valid` (`true` or `false`) for `verify` |
| `replay` | `steps`: `check:N` or `commit:N` joined by commas | `results` (one per `check`), `states` (`top:bits` after each `commit`) |

Error kinds: `BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`.

## Coverage

`scripts/frame/coverage.py` lists every case the file must hold (the check fails on a missing one): E1 to E5; `keys` for directions 1 to 3 at epochs 0, 1, 7, 0xFFFF and 0xFFFFFF; seal refusals (epoch 0x1000000, direction 0 and 4, `kind` 16, an unloaded direction, `tag_len` 0, 5, 32, `ad` of 256 bytes, a body of 256 bytes, a buffer one byte short) and open refusals; plaintext lengths 0, 1, 12, 42, 63, 64, 65, 128, 192, 236, 251; clear parts of 0, 3, 40 bytes; `ad` of 0, 11, 255 bytes; `tag_len` 4, 8, 16; tamper rows for E1 to E3 (a bit of the first and last byte of `ad`, clear part, ciphertext and tag, a changed `msg_id`, `kind`, direction, epoch and key, `clear_len` one too large and, for E3, one too small: E1 and E2 have an empty clear part, so there is no smaller value); the previous-slot rows; the 17-step replay sequence of the contract table, the empty-window rows and the 2^64 - 1 rows; open rows with a window; MAC-only rows (labels of 1 and 32 bytes and the refused 0 and 33, `n` of 4, 8, 16, 32 and the refused 0, 2, 5, messages of 0, 5, 55, 56, 63, 64, 119, 120 and 255 bytes each in one, two and three parts, verify true and false).

## How to check

```
bash fixtures/frame/check-vectors.sh            # reference re-derives every row, coverage, second implementation
bash fixtures/frame/check-vectors.test.sh       # the check fails on a corrupted copy; the generator is deterministic
python3 scripts/frame/gen_vectors.py            # rewrites vectors.txt (never edit it by hand)
```

`scripts/frame/independent_check.py` is a second implementation written from the contract alone (it imports nothing from the reference); it recomputes E1 to E5 and three other rows.

## How a package loads the file

Read each non-comment line, split on spaces, then on the first `=`. Build the call from the input fields, run it, and compare every output field of the row. A row whose output is a `result` other than `Ok` must produce that error kind, nothing written to the output buffer, and (for `open` with a window) a window equal to `window`. The Rust suite (AZ-3203) reads this file through `CARGO_MANIFEST_DIR/../fixtures/frame/vectors.txt`.

## Ring cases

`ring-cases.txt` is not this file: it holds the rows of the cross-language ring (`.github/workflows/ring-frame.sh`, AZ-3338, AZ-3341, AZ-3354), each checked against the reference on every load. Row kinds: `seal`, `mac` (good rows; a `seal` row may end in an `out_len`, the exact buffer), `open` and `verify` (tampered input), and `refuse-seal`, `refuse-open`, `refuse-mac` (refusals by name). `refuse-seal` and `refuse-open` carry `dirs` (digits 1 to 3, the directions the session loaded) and `out_len` (the caller's buffer) before the expected error kind. The refusal cases are those of `vectors.txt` written out as hex; a driver prints the error kind, never aborts, and answers the next line.

A direction outside 1 to 3 cannot be handed to a package whose type has no such value. Java passes `null` (the package answers `BadValue`), Swift calls `FrameDirection(number:)` (the package throws `BadValue`), and Rust has no value to pass: its driver prints `BadValue` where `direction()` has none, as `rust/tests/frame_vectors_tests.rs` reads the same rows. C#, C++, Go, Python and TypeScript hand the number to the package.

