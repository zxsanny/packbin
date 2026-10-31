---
loop: 92
branch: dev
---

# AVR runtime check of chacha20_xor (loop 92)

Source: `_docs/loops/loop91/handoff92.md` (candidates), probed on HEAD e64e3eb on 2026-10-31. The owner chose the AVR `chacha20_xor` check ("AVR chacha20_xor check", 2026-10-31) and confirmed the summary and the change location. No UI.

## Problem

The C++ core builds for the ATmega328P (Arduino Uno, avr-gcc 7.3, 16-bit `int` and `size_t`) and CI links the Uno example, but no AVR image is ever run (`README.md:462`, `cpp/embedded/arm.sh` comment "Build only: no AVR emulator runs the image"). `chacha20_xor` (`cpp/src/core/crypto.cpp:259`) carries a comment that its loop counts down the remaining bytes because "an offset stepping by 64 would wrap a 16-bit `size_t`". That reasoning, the `len / 64` block count and the 32-bit counter-limit test (`blocks - 1 > 0xffffffff - counter`) have run on 32-bit and 64-bit hosts only. The check is to run them on a real 16-bit `size_t` in an emulator, in CI, with a failing gate.

Probed on HEAD (2026-10-31, `packbin-embedded:local`, Ubuntu 24.04):

- `simavr` 1.6 installs from Ubuntu universe (`apt-get install simavr`); `avr-gcc` is already in the image.
- A probe ELF (C `main`, `chacha20_xor` through a C++ shim, linked with `crypto.cpp` built with the Uno flags) linked at 1,908 B of text and 174 B of bss and ran to its end under `simavr -m atmega328p -f 16000000`, exit code 0.
- The simavr console register (`AVR_MCU_SIMAVR_CONSOLE` on `GPIOR0`) printed nothing in 1.6. A plain UART write (`UDR0`, no library header) prints on stdout, wrapped in ANSI colour codes, with the line end shown as `.`. The harness reports over the UART.
- `avr_mcu_section.h` does not compile as C++ (C99 designators), so it is not used.
- A run with interrupts off and `sleep_cpu()` ends simavr with exit code 0.
- Reference first 8 bytes of the stream (key `00..1f`, zero nonce, counter 1) computed independently: `18b84231ade6a6d1`.

## Change location

No UI. Owner confirmed (2026-10-31): the AVR target in `cpp/embedded/arm.sh` (`target_avr_uno`), running `packbin::detail::crypto::chacha20_xor` from `cpp/src/core/crypto.cpp`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The wrap the comment names needs a buffer near 64 KiB; an ATmega328P has 2 KB of RAM and no AVR part has a 64 KiB data space in RAM, so the run cannot reach it. It checks 16-bit `int` and `size_t` arithmetic in the length, block-count and counter-limit paths (lengths 0 to 129, counters at the 32-bit edge), not the wrap region itself | owner informed in the Phase 1 summary ("a real 16-bit `size_t`"); this limit was found after it | open | Medium |
| `simavr` joins the shared `packbin-embedded` image (also run by `rust-embedded`); the package comes from Ubuntu universe at image build | none stated | open | Low |
| simavr stdio output carries ANSI colour codes and shows non-printable bytes as `.`; the gate strips colour codes and uses printable record separators | none stated | open | Low |

## Out of scope

Other crypto functions on AVR (SHA-256, HMAC, HKDF), the emulated cycle count, real hardware, any change under `cpp/src` or `cpp/include`. If the run shows a defect in `chacha20_xor`, the loop stops and reports it (no stub, no weakened expectation).
