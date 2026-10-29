# Batch Report

**Batch**: 1
**Tasks**: AZ-3378_frame_ring_key_id_length
**Date**: 2026-10-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3378_frame_ring_key_id_length | Done | 7 (loader, rows, Rust driver, C++ driver, README, 2 self-tests) | ring 64 pairs 0 mismatched, `58 rows, 0 mismatched` x 8; `ring-frame-drivers.test.sh` 276 checks; `ring-frame.test.sh` 37 PASS | None |

## Code Review Verdict: PASS

No per-batch `/code-review` (owner preference, recorded since loop 70). The parent read the diff of the two drivers, the loader, the rows and both scripts: no finding. Lint: `shellcheck` (koalaman/shellcheck:stable) on the two edited scripts, exit 0; `bash -n` on both; `cargo build` on Rust 1.99.1 and 1.97.0 with no warning; the C++ driver built in `gcc:16` with `-std=c++17 -O2 -Wall -Wextra -Werror`.

CI-parity: PASS. Commands (the steps of the `ring` job and the `scaffold` job of `test.yml` that run the touched scripts): `ring-frame.sh` with all 8 drivers (C++ through `ring-cxx.sh`, `RING_GCC=16`), `ring-frame-drivers.test.sh` (8 languages), `ring-frame.test.sh`. Not run here: `ring-toolchains.sh` (compares the host's Node 22, GCC 15, Rust 1.97 with the CI pins 24, 16, 1.98; it fails on this host by design) and `language-pair.sh` (no change to a pack or unpack command; it runs in step 11 with the `ring` stage).

## Test Suite

Measured on this host (Linux, side JDK 26.0.2.1, Node 22.23.1, Rust 1.99.1, C++ in `gcc:16`, Go and Swift in their containers), HEAD 489d291 plus this batch:

- `ring-frame.sh`, 8 drivers: `ring-frame: 64 pairs, mismatched: 0`; `refusals <lang>: 58 rows, 0 mismatched` for csharp, typescript, python, rust, cpp, java, go, swift (43 on HEAD).
- `ring-frame-drivers.test.sh`: `all passed (8 languages, 276 checks)` (132 on HEAD; 18 new per language).
- `ring-frame.test.sh`: 37 PASS, 0 FAIL (34 on HEAD; `id-padded`, `key-aborts`, `empty-key-and-id-keep-fields` new).
- Non-vacuity, scratch copies with one part put back to HEAD: HEAD Rust and C++ drivers: the driver script fails 18 Rust checks (12 key, 6 id) and 6 C++ id checks, and the ring names `R.seal.id7` and the other `id` rows for C++ (`refusals cpp: 58 rows, 6 mismatched`) and ends the seal phase on `frame line 42: key must be 32 bytes` for Rust; HEAD rows: `id-padded`, `key-aborts` and `empty-key-and-id-keep-fields` fail (3 failures); HEAD loader: `empty-key-and-id-keep-fields` fails (and every stand-in run, since the line loses a field).
- Total: 276 + 37 PASS, 0 failed, 0 skipped; the ring run is a separate green result.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `verify` line with a key of 31, 33 or 0 bytes: all 8 drivers print `BadValue` (probe on HEAD plus Rust after the change) | AZ-3378 Excluded (verify) | no ring row (a verify row answers valid or invalid); `ring-frame-drivers.test.sh` checks `verify-key-31/33/0` in all 8 languages | clear (probe) |
| 2 | HEAD C++ driver cut a 9-byte id to 8 and `open` returned the plaintext of a frame sealed under another id (`R.open.id9 open gave 84b357fa...`, wanted BadValue) | AZ-3378 AC-4 | fixed by the same driver check; the C++ package is not involved | clear |
| 3 | A row that combines a wrong-length key or id with a second refusal (key of 31 bytes and a body of 256 bytes): which error each driver gives first is not pinned | AZ-3378 `scenarios.md` Not walked | no row exists; a later row would show the order | unclear (needs a product decision only if a row is wanted) |
| 4 | The ring needs a JDK and `typescript/node_modules` on a fresh Linux clone; neither was present, and sudo needs a password | none | JDK 26.0.2.1 Temurin tarball (sha256 checked) under `~/.local/share/packbin-jdk26` on the owner's choice, `npm ci` in `typescript/`; the documented path (apt `openjdk-26-jdk-headless`) is still open | clear (owner answer) |

## Commit

`[AZ-3378] Frame ring: key and msg_id length refusals`. Body: the rows, the loader, the Rust and C++ drivers. `Loop: 81`.

## Next Batch: All tasks complete
