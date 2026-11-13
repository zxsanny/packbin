---
title: "A raise of a cpp-m33f pin gets a line here saying what the bytes bought"
applies_when: "raising or re-measuring the m33f_* pins in cpp/embedded/lib.sh, or adding to the C++ frame image"
source: "loop 75 (AZ-3292, frame image pins), loop 97 (AZ-3507, parity percentage)"
---

A raise of a pin in `cpp/embedded/lib.sh` needs a line in this file saying what the bytes bought. Earlier history (25,720 B to 25,760 B in loop 84, AZ-3391) is in [cpp-m33f-row.md](cpp-m33f-row.md).

## Loop 97 (AZ-3507): 25,760 B / 724 B to 25,948 B / 740 B

The `cpp-m33f` pins went 25,760 B / 724 B to 25,948 B / 740 B in loop 97 (AZ-3507, measured on HEAD the same loop): +188 B of flash and +16 B of stack bought the parity percentage (`parity_percent(scheme, p)`: the count of a message from its length, the search for the clear length of a received one, the limit rule). The codec calls stay behind a test of the scheme's setting in the template (`pack`, `unpack`): a `constexpr` scheme without parity folds that test and drops the whole codec from the image, and an out-of-line helper that takes the setting as an argument (`protect_packet` called unconditionally) kept it and cost +1,800 B; a shared `unpack_fields` in place of the inline `unpack_clear` saved 376 B on the M33F but cost 24 B on the Uno, so it was not kept. The string-free ECC-free image (21,688 B) and the Uno example (15,402 B) did not move.

## Loop 75 (AZ-3292): the C++ frame image has its own pins

The C++ frame image (loop 75, AZ-3292: `cpp/embedded/arm/frame_main.cpp`, the frame session and the MAC-only call alone) sits inside the existing `cpp-m33f` row and has its own pins in `cpp/embedded/lib.sh`: `m33f_frame_flash_pin` 8,416 B and `m33f_frame_stack_pin` 912 B (the deepest call is `MacKey::derive`, 976 B raw less the 64 B meter overhead); the existing pins did not move. It is not a new row, so `lib.test.sh` and `run-parts.test.sh` did not change; a new row would need both.
