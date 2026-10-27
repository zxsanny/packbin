# Blackbox Tests 25: frame mode in C++, Go, Python and TypeScript (loop 75, FT-X-166 to FT-X-168)

Source: tasks AZ-3292 (C++), AZ-3293 (Go), AZ-3294 (Python), AZ-3295 (TypeScript), acceptance criteria AC-1 to AC-6 (the same wording in the four specs), contract `pack-session.md` 3.0.0. Loop 71 did the same for C#, Java and Swift (blackbox-tests-24).

## FT-X-166: shared vectors through the public API of four packages

| Item | Value |
|------|-------|
| Input | `fixtures/frame/vectors.txt` (157 rows, E1 to E5, boundary and refusal rows) and `fixtures/crypto/vectors.txt` (27 rows) |
| Expected | every output field of every row matches in C++, Go, Python and TypeScript; the largest epoch works and the next one is `BadValue`; a copy with one expected digit changed fails on that row only (the loader is not vacuous); the bodies equal the Rust, C#, Java and Swift ones |
| Run by | C++ `frame_vectors_host_tests.cpp` (all 157 rows), `frame_tests.cpp` (E1 to E5 on the target), `crypto_vectors_host_tests.cpp`; Go `frame_vectors_test.go`, `crypto_vectors_test.go`; Python `test_frame_vectors.py` (loader `frame_support.py`), `test_crypto_vectors.py`; TypeScript `frame-vectors.test.ts` (loader `support/frame-vectors.ts`), `crypto-vectors.test.ts` |
| Not run by | a ring that exchanges frames between two languages (a candidate, excluded in the specs) |

## FT-X-167: open order, replay window, MAC-only call, refusals and names

| Item | Value |
|------|-------|
| Input | a forged tag; a duplicate counter; a counter 64 or more below the top; a frame sealed under the previous key; the MAC-only call over every split of E4 and E5; load, seal, open and MAC-only arguments out of range; the public API listing |
| Expected | `TagMismatch` (one MAC computed), `Duplicate` and `TooOld` (0 MACs computed), `Ok` with slot `Previous` (and `TagMismatch` after `clear_previous`); the output buffer and the window unchanged on every refusal and the counter committed only after the decrypt; one tag for every split; `BadValue`, `TooLong`, `ShortPacket` and `BufferFull` as the contract orders them, nothing written; the D1 names present (`FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`) and the five error kinds `BadValue`, `BufferFull`, `TagMismatch`, `Duplicate`, `TooOld` beside the existing ones |
| Run by | C++ `frame_tests.cpp` (the four AC-3 results on the target), `frame_api_host_tests.cpp`; Go `frame_open_order_test.go`, `frame_refusals_test.go`, `frame_window_test.go`, `frame_names_test.go`, `errors_test.go`; Python `test_frame_open_order.py`, `test_frame_refusals.py`, `test_frame_replay.py`, `test_frame_mac_only.py`, `test_frame_public_api.py`; TypeScript `frame-open-order.test.ts`, `frame-refusals.test.ts` (with 1,000 seeded hostile opens), `frame-replay-window.test.ts`, `frame-mac-only.test.ts`, `frame-api.test.ts` |

## FT-X-168: lifecycle, concurrency, README examples and the C++ frame image

| Item | Value |
|------|-------|
| Input | a session or a key released (`Close`, `close()`, `clear`, destructor, context manager, `Symbol.dispose`); replacing and clearing the previous slot; the tag compare with a difference in the first and in the last byte; 8 threads or goroutines sealing on one session; Go `Open`, `SetPrevious`, `ClearPrevious` and `Close` from many goroutines under `-race`; the README example of each language; the C++ frame image on QEMU `mps2-an505` |
| Expected | key arrays read zero after release and every later call is `BadValue`; the old previous slot reads zero; the compare folds every byte (no early exit); every body equals the single-thread seal; the README block equals the example test (`scripts/frame/readme-examples.sh`); the C++ frame image links without a heap symbol, runs with 0 malloc/new wrapper calls and 0 failures, and measures 8,416 B of flash and 912 B of stack against the pins `m33f_frame_flash_pin` and `m33f_frame_stack_pin` |
| Run by | C++ `frame_api_host_tests.cpp` (destructors, `clear`, 8 threads), `frame_readme_host_tests.cpp`, `cpp/embedded/arm/frame_main.cpp` through `target_m33f`; Go `frame_wipe_test.go`, `frame_refusals_test.go`, `frame_readme_test.go`; Python `test_frame_wipe_and_compare.py`, `test_frame_concurrency.py`, `test_frame_readme_example.py`; TypeScript `frame-wipe-compare.test.ts`, `frame-readme-example.test.ts` |
| Not run by | a real Cortex-M33F board (QEMU only); an AVR or ESP32 frame image (the frame image is on the `cpp-m33f` row only); TypeScript with several workers (an object is not shared between workers) |
