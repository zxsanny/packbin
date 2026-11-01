# Traceability matrix — loop 97 (AZ-3499 to AZ-3509, AZ-3511 to AZ-3513)

Scenarios FT-X-169 to FT-X-172 and FT-E-16 in `blackbox-tests-26-loop97-parity-percent.md`. Evidence: the batch reports 01 to 06 and `scripts/loop-tests.sh --all --only scaffold,ring,ac10` (3 passed), the eight package suites (Python 4999, TypeScript 3628, C# 5346, Java 11,697 checks, Go ok, Swift 455, Rust 1856, C++ all passed in `gcc:16`) and the full ring (64 pairs, 52,800 rows, 0 mismatched).

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AC-1 | `n = min(32, (p × L + 99) div 100)` for 22,752 pairs, same in eight packages | Covered | FT-X-169 |
| AC-2 | p 0 sends the clear bytes only | Covered | FT-X-169, FT-X-170 |
| AC-3 | bytes equal the fixed-count scheme with `n(p, L)` | Covered | FT-X-169 (`encp`, ring `ring.p*.enc`) |
| AC-4 | largest clear message 251/230/222/222/222; longer refused naming length and limit; p 0 has no limit | Covered | FT-X-169 (`limp`) |
| AC-5 | unpack finds `L` from the received length; round trip for every pair | Covered | FT-X-169 (`inv`, round trip) |
| AC-6 | an impossible length is `uncorrectable`; above 254 is too long | Covered | FT-X-169 (`inv`, `badp`), ring `nolen` rows |
| AC-7 | repair with the real count of the message | Covered | FT-X-171 |
| AC-8 | p 0 as count 0; limit 0 to 16 for p 1 to 100, lowered to `n / 2`; `bad_limit` outside | Covered | FT-X-170, FT-X-171 |
| AC-9 | percentage outside 0 to 100 or with a count refused; last setter wins | Covered | FT-X-170 (a constructor that takes both exists in Python and TypeScript only) |
| AC-10 | dispatch needs one setting; a mix is refused when built | Covered | FT-X-170 |
| AC-11 | old vectors, old tests and fixed-count bytes unchanged | Covered | all old suites green; `vectors.txt` byte-identical |
| AC-12 | work bound plus at most 255 steps; timing checks pass | Covered | AC-10 stage of `loop-tests.sh`; the package timing checks |
| AC-13 | `PACKBIN_NO_ECC` removes it; Cortex-M33F pins within 400 B / 64 B | Covered | FT-E-16 (device behavior: Open, below) |
| AC-14 | contract 1.1.0, ADR-010, README | Covered | documents; README-reading tests green |
| AC-15 | percent vectors read by all eight packages and the reference | Covered | FT-X-169 |
| AC-16 | ECC ring rows under p10, p25, p50, p100: 64 pairs, 0 mismatched | Covered | FT-X-172 |
| AC-17 | optional field: each message carries its own count | Covered | FT-X-172 |
| AC-18 | string read after the repair | Covered | FT-X-172 (C++ bytes branch syntax-checked only) |
| AC-19 | the mix error tells a percentage from a count | Covered | FT-X-170 |
| Open 1 | the percentage on a Cortex-M33F device or QEMU image (the probe does not exercise it) | Open | FT-E-16 (size and link only) |
| Open 2 | CI run of the publish gate and the ESP stage for the new header `codec_ecc.hpp` | Open | CI after the push |
