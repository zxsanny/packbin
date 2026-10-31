# Acceptance criteria - m33f-128k-ram-view

Inherits the ACs of AZ-3189 (`cpp-m33f` row) and AZ-3231 (`rust-m33f` row) unchanged: same vectors, same golden packet, same pins.

**AC-1 Window.** Given the M33F images of `cpp-m33f` (all-kinds, vector runner, baseline, frame) and of `rust-m33f` (baseline and the four feature sets), when linked, then each has its stack top at 0x38020000 (128 KiB above the RAM start 0x38000000) and the link reports no region overflow.

**AC-2 Figures unchanged.** Given HEAD figures, when both rows run in the window, then `cpp-m33f` passes with 315 of 315 vectors, all-kinds flash 25,760 B, stack 724 B, frame flash 8,416 B and stack 912 B, and `rust-m33f` passes with the pins of `limits-m33f.txt` (base 15,132 B / 456 B, text 27,268 B / 2,736 B, ecc 18,764 B / 744 B, frame 20,404 B / 1,728 B).

**AC-3 Overflow.** Given a scratch copy where the all-kinds image carries a zero-initialised array of 130 KiB, when `cpp-m33f` runs, then the row fails and its log shows the linker's RAM-overflow message.

**AC-4 Window moved.** Given a scratch copy where the script's RAM length is 4 MB (or any value other than 128 KiB), when `cpp-m33f` runs and when `rust-m33f` runs, then each row fails naming the expected stack top 0x38020000 and the one found.

**AC-5 Nothing else moves.** Given the change, then compile warnings stay 0, nothing under `cpp/src`, `cpp/include` or `rust/src` changes, the M3, M4F, s390x and AVR rows are unchanged, and no row is added (`lib.test.sh` and `run-parts.test.sh` pass unchanged).

**AC-6 Words match.** Given the change, then the script header, the `lib.sh` comment on the M33F target and the README sentence (if any) say that the images run in a 128 KiB RAM window of the secure alias and that this is not a TrustZone non-secure image.
