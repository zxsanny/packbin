# Static analysis

**Date**: 2026-10-05
**Scope**: `cpp/src/core`, `cpp/include/packbin`, `fixtures/hostile`, `.github/workflows`

| Check | Result |
|-------|--------|
| Heap, exceptions, RTTI in the core | none. The M0+ link check finds `__cxa_*` 0 and heap references 0 (embedded job) |
| Unbounded copies and formatted output | `strcpy`, `sprintf`, `malloc`, `new` do not appear. Every `memcpy` is guarded: `put_bytes` checks `cap - len < n` (`core.hpp:119`); `get_bytes` checks `left() < n` (`core.hpp:129`); `store_text` checks `n > f.size` for fixed storage (`values.cpp:145`); the session copies fixed 16/32/64-byte blocks |
| Integer overflow in sizes | F0 (fixed): a 64-bit count was narrowed to a 32-bit `size_t` in `unpack_small`, `unpack_text` and `item_count`. Counts are now clamped by `clamp_count` before narrowing; the `bits`/`packed` byte length is computed in 64 bits; the capacity check compares in `int64`. Regression vector `wide_count_is_not_truncated` runs on Cortex-M3 QEMU |
| Untrusted-input fuzz | the all-kinds scheme (49 table entries, every kind) packed once (132 bytes), then 20 000 000 mutated packets (byte set, bit flip, truncate, append, 0x00/0xff) were unpacked from exact-size heap copies under AddressSanitizer + UndefinedBehaviorSanitizer (`-fno-sanitize-recover`): 5 711 734 unpacked, 14 288 266 returned an error, 0 sanitizer reports. The host is 64-bit, so the fuzz could not show F0 |
| Hostile vectors | the 17 shared cases run on the host with a 1 s watchdog and canary bytes around the row: 0 hangs, 0 writes outside the row |
| Termination | a repeat round that reads nothing now ends the repeat; any container round that reads nothing ends an unbound container. The earlier path (an unbound `times` with a zero-width body and a `u32` count of 0xffffffff ran about 10 s) was found by review and fixed in batch 5 |
| Secrets | none in the tree. `.env` is untracked; `.env.example` holds no values |
| Shell injection in new scripts | `fixtures/hostile/check-cases.sh` reads a data file with `set -f` and quoted expansions; no `eval` |
| CI downloads | `cpp/embedded/examples.sh:25` fetches the `arduino-cli` tarball without a checksum (F2) |
