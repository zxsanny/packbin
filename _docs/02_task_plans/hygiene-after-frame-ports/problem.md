---
loop: 76
branch: dev
---

# Hygiene after the frame ports (loop 76)

Source: `_docs/loops/loop75/handoff76.md` and `_docs/loops/loop74/handoff75.md` (candidates). The owner chose the hygiene loop on 2026-10-27 and accepted the recommended scope: items 1 to 5 and 7, item 6 investigate-first, the AVR runtime check out. The hopper was empty; the interview is that choice plus the probes below, every figure read from a run on HEAD a50e750 on 2026-10-27 (logs in the session scratchpad).

## Problem

Small defects left open by loops 71 to 75. None changes frame bytes, fixtures, the contract or an embedded pin. The probes changed three of the seven descriptions:

1. **`publish-timing.selftest.sh` failed once at host load near 100** (`printf: write error: Broken pipe`, then "alpha has no timing line"). It has 15 `printf '%s\n' "$out" | grep ...` pipelines under `set -euo pipefail`. The suspected cause (the reader `grep -q` exits on its first match while `printf` still writes) was **not reproduced**: 0 failures in 3,000 runs of the pattern, idle and with 12 CPU burners (load 5 to 12, Apple bash 3.2.57). The cause stays unproven; the loop removes the pattern and makes the next failure show its evidence.
2. **The C# hostile probe does not run at all.** `PackbinProbe.csproj` compiles `ns20/Program.cs` through the SDK default glob: the build warns `CS7022: The entry point of the program is global code; ignoring 'Program.Main(string[])'` and `PackbinProbe <repo> edges` dies with `System.FormatException` at `ns20/Program.cs:5`, exit 134. The handoff called this a cosmetic extra compile; it is a crash. Fix: `<Compile Remove="ns20/**" />` (proved on a scratch copy: build 0 errors, probe runs).
3. **No feature set but the default compiles its tests, and the cause is two-fold.** `cargo test --no-default-features --features frame --no-run` (Cargo 1.79) fails in the library's own test modules, `src/session_core/sha256.rs:190-191` and `src/session_core/hkdf.rs:84-92` (6 errors: `String`, `Vec`, `format!` not in scope, because `extern crate alloc` is gated on the `alloc` feature, which that set does not enable). Cargo stops at that target. Every other set also fails, in the integration targets: `--no-default-features` alone, `alloc`, `text`, `ecc`, `text,ecc`, `frame` and `text,ecc,frame` each print 3 to 8 `could not compile` lines (7 of 7 sets fail; the lists are cut by cargo's stop). The cause is that 24 of the 38 files in `rust/tests/` carry no inner `#![cfg(...)]` attribute, and 22 of them use the std API (`MapScheme`, `Values`, `pack`, `unpack`, ...), so they cannot build without `std`. The suite (`.github/workflows/run-suite.sh`) never hits this because it names each no-std target with `--test <name>`; only a plain `cargo test` in a non-default feature set does. The handoff described the second half correctly and missed the first. Proved on a scratch copy of `git archive HEAD`: an inner `#![cfg(feature = "std")]` on the 22 std-only files, the gate of `nostd_dict_tests.rs` widened from `text` to `all(std, text)` (it uses `nostd_support::random`, which needs `std`), `extern crate std` under `cfg(all(test, not(feature = "std")))` in `lib.rs` and a `use std::{format, string::String, vec::Vec}` under `cfg(not(feature = "std"))` in the two test modules make all 8 sets exit 0 (`--no-run`). The repo's own pattern is the inner attribute (14 files have one); Cargo's `required-features` per `[[test]]` would need 23 manifest entries, so it is not used.
4. **The Swift DocC catalog's "Public names" list (`Packbin.md`, "The whole API is listed here") names none of the 10 public frame types**: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `Freshness`, `ReplayWindow`, `MacKey`.
5. **The reason for the vcpkg `supports: linux | osx` line is stale in two docs, the line itself is not.** ADR-003 line 48 and `05_cpp_package/description.md` line 136 name `os_random` ("has no Windows branch"), which loop 74 deleted. The other reason holds and the README says it: the C++ core is built and tested only with gcc on Linux and clang on macOS, so Windows is not supported. The loop corrects the two docs and keeps the line (dropping it would claim Windows without a Windows build; that is an owner decision, see Flagged concerns).
6. **The C# and Java `edges` probes' NFC/NFD check is a probe error, not a package defect.** With item 2 fixed, C#: 63 PASS, 1 FAIL; Java: 64 PASS, 1 FAIL, both "dict: NFC and NFD forms of é are two keys". The probe passes the keys NFC (`c3 a9`) then NFD (`65 cc 81`); dictionary keys must ascend strictly by UTF-8 bytes (loop 42, `csharp/Walker.Collections.cs:140`), so that order is refused. With the two keys swapped (NFD first) on scratch copies: C# 64 PASS and exit 0; Java 65 PASS and exit 0. The packages are right.
7. **Test and probe names still say "Session"** after the stream session was removed: C# classes `TopRangeAndSessionTests` (`csharp/tests/TopRangeAndSessionTests.cs`, 126 lines) and `EccSessionTextTests` (`csharp/tests/EccSessionTextTests.cs`, 112 lines); probe files `fixtures/hostile/fuzz/python/fuzz_ecc_session.py` and `fixtures/hostile/fuzz/typescript/fuzz_ecc_session.ts`. Names only. Readers found by `git grep`: `fixtures/hostile/fuzz/README.md`, `fuzz_common.py`, `fuzz_common.ts`, and the C# docs (`description.md`, `tests-by-loop.md`, `module-layout.md`).

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-27 (hygiene loop, recommended scope). No UI.

| Item | Place |
|------|-------|
| 1 | `.github/workflows/publish-timing.selftest.sh` |
| 2 | `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` (and `ns20/Ns20Utf8Probe.csproj`, which must still build) |
| 3 | `rust/src/session_core/sha256.rs`, `rust/src/session_core/hkdf.rs` (test modules) and the 22 std-only files of `rust/tests/*.rs` that carry no `#![cfg(feature = "std")]` |
| 4 | `swift/Sources/Packbin/Packbin.docc/Packbin.md` ("Public names") |
| 5 | `_docs/02_document/adr/003_cpp-vcpkg-git-registry.md` line 48, `_docs/02_document/components/05_cpp_package/description.md` line 136 (and line 17 if it states the same reason) |
| 6 | `fixtures/hostile/fuzz/csharp/EdgesText.cs:214`, `fixtures/hostile/fuzz/java/packbin/ProbeEdgesText.java:232` |
| 7 | `csharp/tests/TopRangeAndSessionTests.cs`, `csharp/tests/EccSessionTextTests.cs`, `fixtures/hostile/fuzz/python/fuzz_ecc_session.py`, `fixtures/hostile/fuzz/typescript/fuzz_ecc_session.ts` and the readers listed in item 7 |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Item 1: the cause of the one failure is not reproduced | remove the pattern, print the captured output on a failed match; state "cause unproven" in the record; never claim the flake fixed | open | Low |
| Item 3: after the std gates, a feature set may still fail for a reason other than a missing gate or import | fix in this loop when the cause is a gate, an import or a `cfg`; a product-code defect gets its own task | open | Medium |
| Item 3: the test modules are inside `session_core/`, which the embedded Rust stage compiles | the fix is `#[cfg(test)]` only; the embedded stage figures (rust-m33f pins of `rust/embedded/limits-m33f.txt`) must be unchanged | open | Medium |
| Item 5: should the port drop `supports` and claim Windows? | owner; would need a Windows build and test first, not in this loop | open (owner) | Low |
| Item 7: a rename may break a script or a doc that names the file | `git grep` every reader before the rename and run each (AGENT_GOTCHAS) | open | Low |
| AVR `chacha20_xor` runtime check on a 16-bit `size_t` | out of scope by the owner's choice (needs an AVR emulator) | accepted-risk | Low |
