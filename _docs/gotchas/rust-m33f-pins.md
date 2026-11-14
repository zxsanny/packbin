---
title: "Measure the rust-m33f pins with Rust 1.98.1 after run.sh libs, and record each raise here with what the bytes bought"
applies_when: "running or re-pinning the rust-m33f row of the Rust embedded stage (rust/embedded/limits-m33f.txt)"
source: "loop 70 (AZ-3231), loop 73 (AZ-3275), loop 97 (AZ-3506), loop 98 (AZ-3526, owner 2026-11-01), loop 113 (AZ-4218)"
---

A raise of a pin in `rust/embedded/limits-m33f.txt` needs a line in this file saying what the bytes bought.

## The row and its toolchain (loops 70, 73)

The `rust-m33f` row of the Rust embedded stage (loop 70, AZ-3231) holds each set to the pins of `rust/embedded/limits-m33f.txt` (base 15,132 B / 456 B, text 27,268 / 2,736, ecc 18,764 / 744, session 18,916 / 1,504, frame 20,404 / 1,728; loop 73, AZ-3275: the volatile key wipes bought the HKDF, SHA-256 schedule and stream pad clears for +32 B and +168 B of flash and -24 B of stack each, with the helper out of line as the compiler chose; forced inline gave +128 B / +96 B before the schedule wipe and no stack gain), measured with **Rust 1.98.1**: the Mac default 1.79 gives fewer bytes of flash (frame 19,844 B) but more of stack (frame 1,896 B against the pin of 1,752 B; step 11 of loop 70 failed on it), so `run.sh libs` now selects 1.98 itself (`PACKBIN_EMBEDDED_RUST`, default 1.98; install it with `rustup toolchain install 1.98 --profile minimal -t thumbv7em-none-eabihf -t thumbv8m.main-none-eabihf`).

Run `docker compose -f docker-compose.test.yml run --rm rust-embedded`. The ceilings are the C++ row's (`m33f_*`, 64 KB / 8 KB); a raise of a pin needs a line here saying what the bytes bought. The row needs no other row's log (the route packet comparison with the M4F run went in loop 94; the probe unpacks the sample on the device).

## Loop 97 (AZ-3506): ecc 18,764 B / 744 B to 19,140 B / 752 B

The `ecc` pin of `rust/embedded/limits-m33f.txt` went from 18,764 B / 744 B to 19,140 B / 752 B in loop 97 (AZ-3506, +376 B of flash and +8 B of stack, inside the 400 B / 64 B the task allowed): the 376 B bought the parity percentage in the heap-free core (`ecc_core::parity_count`, `largest_clear` and `clear_length`, the percentage branches of `pack`, `unpack` and `unpack_repair`, the limit of 0 to 16 and its lowering to `n / 2`). The `base`, `text` and `frame` pins did not move because `Scheme::parity_percent` and `with_parity_percent` exist only with the `ecc` feature: an always-present field made `validate` 6 B longer (+8 B of flash in `base`, `text` and `frame`).

The pins are measured by `rust/embedded/run.sh libs` (rebuilds the libraries) then `docker compose -f docker-compose.test.yml run --rm rust-embedded`; the `image` stage alone links the libraries already in `rust/embedded/build/` and shows the old figures.

## Loop 98 (AZ-3526): ecc 19,140 B / 752 B to 19,996 B / 664 B

The `ecc` pin of `rust/embedded/limits-m33f.txt` went from 19,140 B / 752 B to 19,996 B / 664 B in loop 98 (AZ-3526, +856 B of flash, -88 B of stack; owner yes, 2026-11-01): the 856 B bought the probe's own percentage round trip (25 % and 50 % of a 13-byte message, damage of n / 2 bytes, a repair limit of 16 lowered to n / 2, the clear values compared); none of it is library code, since the pin counts the whole probe. The stack pin is lowered to the measured figure.

## Loop 113 (AZ-4218): all four flash pins up

The four pins of `rust/embedded/limits-m33f.txt` went up in loop 113 (AZ-4218, measured with Rust 1.98, the figures before measured again with the check off): base 15,132 to 15,244 B, text 27,268 to 27,372 B, ecc 19,996 to 20,100 B, frame 20,404 to 20,516 B of flash (+112, +104, +104, +112 B); the stack pins (456, 2,736, 664, 1,728 B) did not move. The bytes bought the rule "a repeat is the last thing a packet reads" in the heap-free API: one pass over the scheme table in `nostd::validate` that answers `SchemeInvalid` for an entry that can write a byte after a `repeat`. `validate` runs first in every heap-free `pack` and `unpack`, as for every other scheme rule there, so on the device the pass is paid per call and not once.

## Loop 126 (AZ-4302): all four flash pins up, two stack pins up

The four pins of `rust/embedded/limits-m33f.txt` went up in loop 126 (AZ-4302, Rust 1.98, QEMU rust-m33f): base 15,244 to 15,412 B of flash and 456 to 472 B of stack, text 27,372 to 27,540 B (stack 2,736 as it was), ecc 20,100 to 20,268 B and 664 to 680 B, frame 20,516 to 20,684 B (stack 1,728 as it was): +168 B of flash in all four, +16 B of stack in base and ecc. The bytes bought the depth check of the heap-free `validate` (a scheme nested more than 256 levels is refused, contract `scheme-depth.md`): one `depth` step and one shared descent in `table.rs` (`parent_and_levels`; `parent_of` is its wrapper). Rejected: a stateful scan with a parent hand-over (+304 B, over the task's 256 B) and `+=` instead of `saturating_add` (clippy `arithmetic_side_effects`, 60 B larger).
