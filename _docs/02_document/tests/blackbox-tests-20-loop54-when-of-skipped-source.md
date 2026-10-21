# Blackbox tests 20 — a `when` of a skipped source, and the C# repeated-text reuse (loop 54)

Loop 54 (AZ-2815, AZ-2816, AZ-2823). Two cases join `fixtures/hostile/cases.txt` (72 cases now) and run in all eight packages.

## FT-X-130: `pack_when_of_skipped_source` and `pack_when_of_skipped_source_zero`

| Item | Value |
|------|-------|
| Scheme | `u8 mode; when(mode == 1) { u16 a; u8 k }; when(k == 2 or 0) { u8 b }` |
| Row | `mode = 0`, `a = 7`, `k = 2` (or `0`), `b = 5` |
| Expected | `bytes` `0100` in all eight packages: the source `k` sits in a clear `when`, so it is absent and the second `when` is false |
| Run by | TypeScript, Python, Java, C# (dictionary rows), Rust (std and no-heap core), C++ (typed row; plain members in the zero case), Go, Swift |
| Not run by | none |
| Before | C++ packed `010005` and its own unpack refused it (`TrailingBytes`); a plain unread source read 0 and matched `when(k == 0)` on unpack |

C++ unit rows (`cpp/tests/core/when_skipped_source_host_tests.cpp`): scheme `k == 2` and `k == 0`, `mode` 0 and 1 (`0100`, `010107000205`, `010107000005`), a source two `when`s deep, one `when` that holds source and consumer, plain members, and the 255-entry link limit (254 fillers build, 255 and 300 refused).

## FT-X-131: C# repeated text

`CompactTextTests+RepeatedTextSpeed` (1 s load-aware and 0.25 s load-aware headroom, 24 to 36 ms idle) and `CompactTextTests+RepeatedTextReuse` (changed text mid-run, alternating, last character only, compact then raw, text-empty-text, two calls in a row): every packet equals the one-by-one encoding.

## Stage 11 at the loop 54 close

`scripts/loop-tests.sh`: 13 stages passed, 1 skipped as unchanged (`publish-gate`), 0 failed, 836 s. Embedded: Cortex-M4F flash 7,952 B of 8,192 (margin 240 B), stack 504 B of 512 (margin 8 B).
