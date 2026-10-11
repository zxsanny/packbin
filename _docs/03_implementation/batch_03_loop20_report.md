# Loop 20 batch 03 report (wave 2: hostile `pack` cases, AZ-2367)

Date: 2026-10-11. One worker; HEAD at start 2d8fe13.

## Result

Seven cases added to `fixtures/hostile/cases.txt` (33 to 40 lines, pack cases 12 to 19) and `README.md`, replayed by all six loaders. `check-cases.sh`: `hostile cases ok: 40`; `cases.test.sh` passes.

| Case | TS | Py | Java | C# | Rust | C++ |
|------|----|----|------|----|------|-----|
| `pack_lone_utf8_under_times_over_budget` | run | run | run | run | run | skip (caller buffer, fixed Array) |
| `pack_element_times_over_budget` | run | run | run | run | skip (no `times` in a list element) | skip |
| `pack_slots_over_limit` | run | run | run | run | run | skip |
| `pack_repeat_over_limit` | run | run | run | run | run | skip (fixed Array) |
| `pack_split_count_zero_after_byte_list` | run | run | run | run | run | run |
| `pack_split_count_zero_after_byte_scalar` (`010000`) | run | run | run | run | run | skip (typed row holds an Array) |
| `pack_flags_skipped_count_with_values` | run | run | run | run | run | run |

The lone-scalar hex `010000` is identical in the five packages that can write a lone scalar (the wave 1b fixes in Python and Rust hold). The slots row has width 65 in all five and refuses with the same text.

Suites: TypeScript hostile 60/60 (53 before); Python hostile vectors 34/34 (27 before); Java `PackbinTest` checks 1952 (1938), api-check PASS; C# full suite 1001/1001 on net10.0 (994), netstandard2.0 not re-run (same test code); Rust `cargo test hostile` 9/9; C++ gcc:16 `make test` pass after `make -C cpp clean`. Edited loader files: `typescript/tests/support/hostile-pack.ts`, `typescript/tests/hostile.test.ts` (new `PACK_REFUSAL` table so a wrong-reason `RangeError` cannot pass), `python/tests/hostile_support.py`, `java/.../HostileVectorTest.java`, `csharp/tests/HostilePackVectorTests.cs`, `rust/src/hostile_tests.rs` (new `PACK_NOT_RUN` skip table, 491 lines), `cpp/tests/core/hostile_pack_cases.hpp` (the C++ pack handlers live there, not in `hostile_host_tests.cpp`).

Time per case (over 2 s are kept at spec size; the total review decides): Python element 7.1 s, Python slots 3.3 to 4.2 s, Rust debug slots 8.1 s, TypeScript slots 1.45 s; every other case under 1 s.

## Discovered during implementation

| Spec ref | What | Handling | Clear |
|----------|------|----------|-------|
| AZ-2367 | Python, Java and Rust hostile loaders assert refusal only, not which rule fired (TypeScript and C# pin the member) | optional message-table follow-up, loop 21 | unclear |
| AZ-2367 | slow cases (above) | total review: accept, release build for the Rust hostile test, or a smaller-limit variant | unclear |
