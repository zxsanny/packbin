---
loop: 81
branch: dev
---

# Frame ring: key and msg_id length refusals

Owner decisions (2026-10-29, loop 81 intake): candidate picked from `handoff81.md` ("key and message-id length refusals in the ring", U1 of loop 77); how Rust and C++ answer: **their drivers print `BadValue` themselves** where the package cannot be handed the value, documented in the README (the step of loop 78 for Rust directions 0 and 4). Not taken: a `skip=` list in the row; leaving U1 out. Probed on HEAD 489d291 (Linux, Ubuntu 26.04; python 3.14.4, dotnet 10.0.400, node 22.23.1, rustc 1.97.1, g++ 15.2, Temurin 26.0.2.1; Go and Swift in their containers).

## What and why

The ring (`.github/workflows/ring-frame.sh`, rows in `fixtures/frame/ring-cases.txt`) has no row for a key that is not 32 bytes or a `msg_id` that is not 8 bytes. Six packages take a byte string and answer `BadValue`. Rust takes `&[u8; 32]` and an 8-byte id, C++ an 8-byte id, so those packages cannot be handed a wrong-length value; loop 77 (U1 = A) left the rows out for that reason, and `fixtures/frame/vectors.txt` and the per-package tests are the only cover. The drivers of those two languages also do not answer `BadValue` today (below), so the rows cannot be added before the drivers change.

Probe on HEAD 489d291, `ring-frame.sh` with the real drivers: `ring-frame: 64 pairs, mismatched: 0` and `refusals <lang>: 43 rows, 0 mismatched` for 8 languages. The same ring with 12 extra refuse rows (a key of 31 and of 33 bytes in seal, open and mac; a `msg_id` of 7, 9 and 16 bytes in seal and open), seven languages (Rust excluded, see below):

| language | key 31 / 33 (seal, open, mac) | msg_id 7 / 9 / 16 (seal, open) |
|---|---|---|
| C#, TypeScript, Python, Java, Go, Swift | `BadValue`, `refusals <lang>: 55 rows, 0 mismatched` | `BadValue`, 0 mismatched |
| C++ | `BadValue` | `refusals cpp: 55 rows, 6 mismatched`: seal sealed a body (`R.probe.seal.id7 seal gave 2bc4ef0b34bb091e4ea0efb2b563b274, wanted BadValue`), open gave `TagMismatch` (`R.probe.open.id7 open gave TagMismatch, wanted BadValue`); `msg_id` is padded or cut to 8 bytes (`handoff.cpp` lines 482, 502) |
| Rust | the seal phase ends `frame line 42: key must be 32 bytes` (a parse error, exit 1, no answer); `key32` in `frame.rs` | `msg_id8` pads a short id with zeros (a sealed body for the wrong id) and refuses a long id as a parse error |

Zero length: a key or `msg_id` of `-` (empty) cannot reach any driver. `scripts/frame/ring_frame.py` writes `key.hex()` and `msg_id.hex()` (lines 247 to 297), an empty string for an empty value, so the line loses a field and all 8 drivers refuse it as malformed (`frame line 42: bad hex: 3`; Go `bad dirs: 300`). `hx()` (line 53) already writes `-` for the other fields.

Every figure above was read from a run in this loop on HEAD 489d291 (logs in the session scratchpad).

## Code sections / UI locations for this loop

No UI. The frame ring harness only:

- `scripts/frame/ring_frame.py`: the lines written for `key` and `msg_id` (seal, open, mac, verify; lines 247 to 297) use `hx()`.
- `fixtures/frame/ring-cases.txt`: 15 new refuse rows and the header comment.
- `.github/workflows/drivers/handoff-rust/src/frame.rs`: `key32`, `msg_id8` and their callers in `seal`, `open`, `mac`, `verify`.
- `.github/workflows/drivers/handoff.cpp`: `frame_seal`, `frame_open` (the `msg_id` copy).
- `fixtures/frame/README.md`: the paragraph on drivers that answer `BadValue` themselves (line 53).
- `.github/workflows/ring-frame.test.sh` and `.github/workflows/ring-frame-drivers.test.sh`: new cases.

## Acceptance criteria

- AC-1: `ring-cases.txt` holds 15 new refuse rows, each `BadValue` and confirmed by the reference on load: `R.seal.key0`, `key31`, `key33`, `id0`, `id7`, `id9`; `R.open.` the same six; `R.mac.key0`, `key31`, `key33` (a zero-length value is written `-`).
- AC-2: the real ring (8 drivers, built and started as `ring-frame.sh` does): `ring-frame: 64 pairs, ... mismatched: 0` and `refusals <lang>: 58 rows, 0 mismatched` for 8 languages (43 on HEAD plus 15).
- AC-3: the Rust driver prints `BadValue` for a seal, open, mac or verify line whose key is not 32 bytes and for a seal or open line whose `msg_id` is not 8 bytes: no parse error, no zero padding. `ring-frame-drivers.test.sh` has the check for Rust.
- AC-4: the C++ driver prints `BadValue` for a seal or open line whose `msg_id` is not 8 bytes (HEAD: a sealed body, or `TagMismatch`). `ring-frame-drivers.test.sh` has the check for C++.
- AC-5: `ring_frame.py` writes `-` for an empty key or `msg_id`; with the HEAD loader the zero-length rows are refused as malformed by 8 of 8 drivers, with the fix none is. `ring-frame.test.sh` has the case (a stand-in driver reads the line as one token per field).
- AC-6: the new rows can fail: with the HEAD Rust and C++ drivers put back, the ring is red and names the rows (Rust: the seal phase fails on the key rows; C++: `R.seal.id7`, `R.open.id7` and the other `id` rows by name). A stand-in driver that pads or cuts the `msg_id` makes `ring-frame.test.sh` exit 1 naming `R.seal.id7`.
- AC-7: the other 6 drivers need no change (probe above); the new check in `ring-frame-drivers.test.sh` runs for all 8 languages and passes.
- AC-8: `fixtures/frame/README.md` says that for Rust (key, `msg_id`) and C++ (`msg_id`) the driver, not the package, prints `BadValue`, in the words used for directions 0 and 4.

Out of scope: multi-part MAC rows; a `verify` row with a wrong-length key (a `verify` row answers `valid` or `invalid`, so it cannot carry `BadValue`; the Rust `verify` uses the same helper as AC-3 and is checked by the driver test only); the per-package vector tests; any other field (labels, `ad`, `tag_len`, `n` are covered).

## Expected input and output

| Line sent to a driver (`frame-batch`) | Rust, C++, the other six |
|---|---|
| `seal <key of 31 bytes> 3 1 4 <msg_id of 8> 2 ... 123 300` | `BadValue` |
| `seal <key of 32> 3 1 4 <msg_id of 7 or 9 bytes> 2 ... 123 300` | `BadValue` |
| `open <key of 33> ...`, `open <key> ... <msg_id of 7 or 9>` | `BadValue` |
| `mac <key of 31 or 33> 9 6e6574 4 <message>` | `BadValue` |
| `seal - 3 1 4 <msg_id> ...` (empty key), `seal <key> 3 1 4 - ...` (empty id) | `BadValue` |
| the 64 pairs of good rows | unchanged: equal to the reference |

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| For Rust (key, `msg_id`) and C++ (`msg_id`) the driver, not the package, gives the `BadValue` answer | owner 2026-10-29, same as directions 0 and 4 (loop 78); stated in the README (AC-8) | accepted-risk | Low |
| No ring row feeds a wrong-length key to `verify` (a `verify` row has no way to expect `BadValue`) | out of scope above; the driver test covers the Rust path | open | Low |
| This probe ran on Linux with a side JDK (`~/.local/share/packbin-jdk26`), Node 22, GCC 15 and Rust 1.97; CI pins Node 24, GCC 16 and Rust 1.98 | CI's `ring` job is the first run on the pinned toolchains (the push of the close) | open | Low |
