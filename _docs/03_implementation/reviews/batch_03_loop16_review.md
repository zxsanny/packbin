# Code Review Report

**Batch**: 3 (loop 16): AZ-2115 (TS part), AZ-2135 (TypeScript, Java and C++ shares), AZ-2103 (TypeScript, publish path); AZ-2099, AZ-2193, Python `bitwhen` ring (harness) | **Date**: 2026-10-06 | **Mode**: Full, one read-only reviewer for TypeScript with the npm build, Java, C++ and the harness, then a fix pass | **Verdict**: PASS_WITH_WARNINGS

Verdicts as first reported: TypeScript PASS_WITH_WARNINGS, Java PASS_WITH_WARNINGS, C++ PASS_WITH_WARNINGS, harness PASS_WITH_WARNINGS. No Critical or High.

## Owner decisions taken during the batch (2026-10-06)

1. AZ-2103 needs two TypeScript-only hunks in the owner's uncommitted `publish-check.py` and `publish-phases.test.sh`: option A, edit only those hunks and commit only them (patch route); the owner's C# hunks stay uncommitted and byte-identical (verified by hash before and after).
2. AZ-2193, GCC 16 is not on any hosted runner: option A, compile C++ in the `gcc:16` image through a `CXX` wrapper (`-static`).
3. Java, a flag byte read inside a nested row leaks out and rebinds later outer bits: option A, fix now.
4. C++, scope rule skips only a closed `when` while Rust, TypeScript and Java also treat `flags` members and flag-bit children as conditional: option B, follow-up spec.

## Findings and disposition

| # | Pkg | Severity | Category | Title | Disposition |
|---|-----|----------|----------|-------|-------------|
| JA-F1 | Java | Medium | Bug (pre-existing, now reachable) | A flag byte read inside a nested row rebinds later bits of the outer row (`010101010203` unreadable) | FIXED (owner A): a nested row binds on a copy of the visible map; probe now packs `010301010203`; 180,000-seed differential: no scheme without a leak changed |
| CP-F1 | C++ | Medium | Bug (outside the ACs) | Scope rule skips only `when`; a flag byte inside a `flags` member or flag-bit child stays visible to later bits (`01000013` unreadable; Rust, TypeScript, Java give `01010013`) | HELD (owner B): follow-up spec |
| TS-F1 | TypeScript | Medium | Maintainability | Outer-first numbering of nested same-handle bits pinned by no test | FIXED (test; reverting the order fails exactly it) |
| HW-F1 | harness | Medium | Spec-Gap / owner call | `ring` also gates a `v*` tag publish through `publish.yml` calling `test.yml` | Accepted (consequence stated to the owner when option A was chosen); recovery is "Re-run failed jobs" |
| HW-F2, TS-F5 | docs | Medium / Low | Spec-Gap | `ci_cd_pipeline.md`, `module-layout.md`, component descriptions, README upgrade note stale | Step 13 docs pass |
| HW-F3 | harness | Low | Maintainability | An errexit death left no record of which command failed | FIXED (`ERR` trap names the command, with `PIPESTATUS`) |
| HW-F5, HW-F6 | harness | Low | Maintainability | `RING_*` versions not tied to the suite tags; gaps and false results in the wiring check | FIXED (tied to `docker-compose.test.yml`; strictness cases added; 28 corrupted copies rejected) |
| TS-F3 | TypeScript | Low | Maintainability | New `src/ is in the tarball` guard had no negative test | FIXED (three tarball layouts in `publish-npm.test.sh`, mutation-checked) |
| JA-F3, JA-F4 | Java | Low | Style / Maintainability | `bit()` Javadoc lint, dead `FlagGroup.bits()` | FIXED |
| CP-F3 | C++ | Low | Spec-Gap (tests) | Only one test killed the `unpack_when` restore | FIXED (round and nested `when` tests; reverting `unpack.cpp` now fails 6) |
| TS-F4 | TypeScript | Low | Spec-Gap (consumer) | `.d.ts` keep `./x.ts` specifiers: TS 4.9 fails TS2691 without `skipLibCheck` | Documented (TypeScript 5.0 or newer) |
| TS-F2, CP-F2 | TypeScript, C++ | Low | Bug (pre-existing) | A same-handle split bit inside a combined `flags` under a split bit is dropped; a `flag_bit` used directly as a `flags` member is never present | Open, same class as the held AZ-2128 concern |
| JA-F2, JA-F5 | Java | Low | Maintainability | Different first error for a scheme with two defects; repeat marker per position | Accepted (no scheme changed from accepted to refused or the reverse) |
| CP-F4 | C++ | Low | Performance | Each nested `when` adds a 32 B frame | Accepted; embedded stack unchanged at 488 B of 512 B, flash 7728 B to 7784 B of 8192 B |
| HW-F4, HW-F7, HW-F8 | harness | Low | Maintainability / Security / latent | Consumer failure not named in the ring log; the gcc container needs neither network nor a writable repo; `find | head` under pipefail | Not done (the spec says `language-pair.sh` does not change; container hardening is the owner's call) |

## Existing tests changed

TypeScript `bool-flag.test.ts` "ninth flag bit is a scheme error": the same `RangeError` on the same nine bits now fires at `scheme(...)` instead of `.bit()` (spec-forced, kept intent). Nothing else.

## Mutation and differential evidence

TypeScript: 8 of 9 new AZ-2135 tests fail with the HEAD sources, finer mutations of `bindFlagBits` each fail 2 to 3 tests; 45k random schemes: no binding or byte difference when each handle is read once and bits are in field order. Java: 180k random schemes against HEAD classes in map and typed modes, identical for every buildable scheme without handle reuse; about 1M hostile packets without a throw or a call over 200 ms. C++: 27 hand and 300 random schemes agree across C++, TypeScript, Java and Rust except the two shapes above; 6,429 rows pack, unpack and repack equal; ASan and UBSan fuzz of 332k packets clean. Harness: the old harness against the new self-test goes red in 16 to 20 checks; healthy ARM and ESP targets pass under the new harness; the `||` guard behaves the same on bash 3.2 and 5.2. AC-6 measured by the parent on `packbin-embedded:local`: with a broken `arm-none-eabi-nm` the old harness exits 0 with 4 PASS, the new one exits 1 with FAIL for `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f`.

## Not checked

C#, the owner's uncommitted work (other than the two TypeScript hunks), amd64 images, the Pico and Arduino examples on a cold cache, the `ring` job end to end (the Ubuntu runner is the only proof), a real Vite build of the packed package, shellcheck (not installed).
