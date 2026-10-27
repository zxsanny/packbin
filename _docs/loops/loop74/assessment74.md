# Feature assessment — loop 74

loop: 74
feature: remove-stream-session
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-10-27
**Implement pass**: batches 01..04 (b6a0f73, 0df534e, b86d468, df01e11), reports `_docs/03_implementation/batch_0{1,2,3,4}_loop74_report.md`
**Verdict**: CLARIFY — 13 covered / 3 out-of-scope / 0 gap-clear / 1 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A v0.3.0 user calls `PackSession` after upgrading | covered | AC-1 (AZ-3281..AZ-3288); greps 0 hits per package, Python `test_star_import.py` (absence guard), TS crypto-vectors entry-exports check, Go `go doc` 0; README upgrade note | intake |
| S2 | meshbell's Rust code uses the frame `Session` | covered | AZ-3289 AC-1, AC-2; `cargo doc` lists the D1 names; `frame_vectors_tests`, lib `frame_` 12/12; README upgrade note names the rename | intake D1 |
| S3 | A Rust user enables `session` | covered | AZ-3284 AC-1; `cargo build --features session` refused; `Cargo.toml` | inventory |
| S4 | A frame user seals and opens after the renames | covered | AC-2; 157/157 in Rust, C#, Java, Swift (`frame_vectors_tests`, `FrameVectorTests`, `FrameVectorsTest`); `fixtures/frame/vectors.txt` SHA-256 unchanged | intake |
| S5 | Clear pack and unpack with parity bytes | covered | AC-3; each package's ECC tests (mixed files kept their clear halves; counts in the batch reports); ring ECC 64 pairs, 0 mismatched | inventory §3 |
| S6 | The ring runs every pair | covered | AZ-3280 AC-1, AC-2; `ring-wiring-*.test.sh`; ring PASS after each batch | inventory §4 |
| S7 | The Rust embedded stage | covered | AZ-3284 AC-4, AZ-3289 AC-2; `rust/embedded/run.sh host` every figure equal to HEAD; `checks.test.sh` | measured |
| S8 | C++ embedded stage and ESP-IDF example | covered (ESP-IDF stage pending CI) | AZ-3286 AC-3, AC-4; arm stage 0 failed, pins equal; ESP-IDF example compiled with host clang and `gcc:16 -fsyntax-only`; the ESP-IDF build itself runs in CI | inventory §6 |
| S9 | A Java caller passes an int direction | covered | AZ-3290 AC-1, AC-3; `javap -public` (no int fields), `FrameMacRefusalsTest` null and not-loaded directions | intake D1 |
| S10 | Crypto vectors in each package | covered | AC-5; 27/27 in all 8 (`crypto_vectors_tests.rs`, `CryptoVectors.cs`, `CryptoVectorsTest.java`, `CryptoVectorTests.swift`, `crypto_vectors_host_tests.cpp`, `crypto_vectors_test.go`, `test_crypto_vectors.py`, `crypto-vectors.test.ts`), mutant copies caught | intake D2 |
| S11 | The hostile corpus `ring_session` line | covered | loaders count lines dynamically; Rust `nostd_hostile_tests`, Python and Swift fuzz suites pass | inventory §4 |
| S12 | A Go or npm consumer installs the next release | covered | AC-6; `go mod tidy -diff` none, `go_deps` only `x/crypto`; npm `dependencies` only `@noble/hashes` | intake D2 |
| D1 | "Duplicate type before parity mix" lost its session half in every package | covered | moved to the clear unpack call in C#, Java, Python, Swift, Go, Rust, TypeScript (batch reports 1-3) | batches 01-03 |
| D2 | Swift `Freshness` was nested in `ReplayWindow` (a D1 name mismatch) | covered | moved to top level (b86d468); Swift frame tests 39 passed | batch 03 |
| D3 | The new frame-port packages' crypto header placement (C++ `src/core`), `checkSize` export (TS), wipe in TS crypto | out-of-scope | D4: frame ports are loop 75 (AZ-3292..AZ-3295 `### Scope`) | batches 02, 03 |
| D4 | Pre-existing issues found on the way: C#/Java `edges` probe "NFC and NFD forms of é" FAIL at HEAD; C# probe csproj compiles `ns20/Program.cs`; Rust `--no-default-features --features frame` all-targets test build fails at HEAD; Swift DocC lists no frame types; vcpkg `supports: linux \| osx` reason gone with `os_random` | out-of-scope | not part of this feature (each exists at HEAD 10cc0be or is an opportunity); leftovers for the loop record | batches 01, 02, 04 |
| D5 | Test and probe names that still say "Session" (`EccSessionTextTests`, `TopRangeAndSessionTests`, `fuzz_ecc_session.*`) | out-of-scope | names only, no behavior; renaming changes test ids and README references | batches 01, 03 |
| D6 | Java has no `FrameConfig` and no `FrameDirections`: `FrameSession.load(key, epoch, tagLen, FrameDirection...)` | gap-unclear | question below | batch 03 |

### Gaps that need a decision (gap-unclear)

#### D6: Java's load arguments against the shared `FrameConfig` / `FrameDirections`

**What is not decided**
Decision D1 said one name set in Rust, C#, Java and Swift, including `FrameConfig` (the tag length and the directions together) and `FrameDirections` (a set of directions). For Java it named only the moves (`FrameSlot`, `FrameOpened`, `FrameSealed`) and the `FrameDirection` enum, and the Java spec followed that, so Java's `load` takes the tag length and the directions as separate arguments. Rust, C# and Swift load with a `FrameConfig`. The four packages ported in loop 75 will copy one of the two shapes.

**Options**
- **A — Add `FrameConfig` and `FrameDirections` to Java**: `FrameSession.load(key, epoch, new FrameConfig(4, FrameDirections.of(FrameDirection.UP)))`, the same shape as Rust, C# and Swift; the varargs `load` goes (0.x). Trade-off: one more small Java task now (about 2 points, the Java suite again), and two more Java types.
- **B — Keep Java's arguments**: `load(key, epoch, tagLen, FrameDirection...)`, the usual Java form; the README and the contract already say Java differs here. Trade-off: the one place where the shared shape differs, and the loop 75 ports need their own choice.

**Recommendation**: A — "match everywhere" was the owner's instruction, and the four ports copy the shape next loop.

### Gaps that are clear (gap-clear)

none

### Not walked

- none (12-row cap not reached)

### Harness gaps

- none: every batch report of this loop has its `## Discovered during implementation` table.

**Owner answer (2026-10-27, AskQuestion "Java shape")**: A — "Add them (Recommended)". New spec AZ-3322_java_frame_config (2 points); router: `new-task --clarify` → implement → feature-assess round 2.

## Round 2

**Date**: 2026-10-27
**Implement pass**: batch 05 (9f68eb4), report `_docs/03_implementation/batch_05_loop74_report.md`
**Verdict**: COMPLETE — 6 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (new rows this round; the 13 + 3 rows of round 1 are unchanged)

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D6 | A Java caller loads a frame session | covered | AZ-3322 AC-1: `javap -public` shows `FrameConfig`, `FrameDirections` and one `load(byte[], int, FrameConfig)`, 0 varargs loads; `FrameSession.java` `load`; README Java example and `FrameReadmeExample.java` | assess-round-1 |
| E1 | Java loads with a null config, a null direction set, or a tag length other than 4, 8, 16 | covered | AZ-3322 AC-3: `FrameConfigTest` (3 load refusals give null) ; `FrameSession.java` `load` | batch 05 |
| E2 | Java loads with an empty direction set | covered | `FrameConfigTest.anEmptySetLoadsASessionThatRefusesEveryCall` (load succeeds, seal and open in UP, DOWN, GROUP are `BadValue` and write nothing); same behavior as C# `FrameRefusalTests.Ac3_LoadWithNoDirectionGivesASessionThatRefusesEverySealAndOpen`, Rust `seal.rs`, Swift `checkCall` | batch 05 discoveries |
| E3 | A call in a direction outside the loaded set | covered | `FrameConfigTest` (`of(UP)` refuses `seal(DOWN)` and `open(GROUP)` as `BadValue`, `seal(UP)` works); `FrameMacRefusalsTest` not-loaded-direction checks | batch 05 |
| E4 | Frame bytes after the load-shape change | covered | AZ-3322 AC-2: `frame vectors: 157 rows checked, 0 mismatches`; `CryptoVectorsTest` 27 rows | batch 05 |
| E5 | The README Java frame example after the change | covered | AZ-3322 AC-4: `scripts/frame/readme-examples.sh` PASS for C#, Java, Swift and Rust; the five docs and the contract no longer say Java lacks `FrameConfig` or `FrameDirections` (`git grep` of the old phrases: 0 hits outside history records) | batch 05 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- none

### Harness gaps

- none: `batch_05_loop74_report.md` has its `## Discovered during implementation` table.
