# Feature description — Rust no_std, heap-free core

**Slug**: rust-nostd-core · **Loop**: 50 · **Epic**: AZ-2750 · **Points**: 13 as a feature, 34 summed over eight slices (re-estimated from the 5 in the first `AZ-2749` spec; see Sizing) → `/decompose --feature`.

## Description

The Rust package gets a second, buffer-based API, `packbin::nostd`, that builds with `#![no_std]` and no allocator for `thumbv7em-none-eabihf` (meshbell: nRF52840 relays, packs and smart devices; an ESP32 station radio). The owner chose this approach on 2026-10-20 (option B, "port the C++ heap-free core"): schemes are plain `const` data, the caller passes input and output buffers and, for compact text, scratch words; every call returns a `Result`; no `unwrap`, `expect`, panicking index or unchecked arithmetic is reachable from untrusted bytes. The existing std API (`MapScheme`, `Values`, `pack`, `unpack`, `PackSession`) does not change and wire bytes do not change. Cargo features: `std` (default), `alloc` (convenience wrappers that return `Vec<u8>`), `text` (compact text), `ecc` (message error correction, off by default), `session`. CI builds the profile for `thumbv7em-none-eabihf` per feature set, publishes flash and stack figures, and fails when a heap symbol or a panic path is linked into decode.

Inputs: `_docs/02_tasks/todo/AZ-2749_rust_nostd_core.md` (AC-1 to AC-4), the C++ core as the reference design (`cpp/include/packbin/core.hpp`, `table.hpp`, `fields*.hpp`, `codec.hpp`, `ecc.hpp`, `session.hpp`, `cpp/src/core/*`), `_docs/AGENT_GOTCHAS.md` (C++ budgets, load-aware timing, worker rules), `fixtures/` (golden, text, ecc, hostile).

## Fit (Part A, today → after)

| Area | Today | After | Who depends on today | Collision |
|------|-------|-------|----------------------|-----------|
| Rust crate (`rust/`) | std only; `Values` is a `HashMap<Rc<str>, Option<Value>>`, `Value` owns `Vec`/`String`/`BTreeMap`; schemes are `Vec`-based and closure-built; `pack` returns `Vec<u8>` | the same API under `std`; `nostd` module (`packbin::nostd`) with no `std`/`alloc` use; `lib.rs` becomes `#![cfg_attr(not(feature = "std"), no_std)]` | `ring` driver `drivers/handoff-rust`, `rust/tests/*`, crates.io publish (`publish-*.sh`), meshbell | the crate has no features today: a new default `std` feature must keep `cargo test` and the publish gate unchanged |
| Shared algorithm code | `ecc.rs` (tables are `const`, but errors and buffers use `Cow`/`Vec`), `session/sha256.rs`, `hkdf.rs`, `pad.rs`, `walk/text_tables.rs`, text codec `walk/text/*` (uses `Vec`) | tables and pure functions shared by both walkers; the core text codec uses caller scratch like `cpp/src/core/text_encode.hpp` | the std walkers and their tests | two walkers in one crate (a second code path for the same format) |
| CI (`.github/workflows/test.yml`, `cpp/embedded/*`) | the `embedded-arm` job runs the C++ image under QEMU (mps2 linker script, semihosting, stack meter) and reports flash and stack against 8,192 B and 512 B | a job for the Rust image on the same startup and meter; sizes per feature set | `scripts/publish-jobs.test.sh`, `ring-wiring` tests read job lists | a new job name must be added to the job guards |
| Fixtures | golden fixture, text vectors, ecc vectors, hostile `cases.txt` are replayed by the std walker | the same files replayed by the core walker, plus a differential test (std pack equals core pack) | the other seven packages read the same files | none: files do not change |
| Toolchain | Rust 1.79 on this Mac, `RING_RUST` pin in CI | target `thumbv7em-none-eabihf` added (rustup component) | CI install step, `ring-toolchains.sh` | a new toolchain component is a download in CI and on this Mac (asked before it is run) |

## Fit decisions (Part C)

- **Card 1 — how the core reads and writes a caller's row.** Rust has no pointer-to-member. Option A: the caller implements a `Row` trait with getters and setters by field id (plain `match`). Option B: a macro that generates it from a struct. Option C: a function pointer per field in the scheme. **Chosen A (recommended: simplest, no macro and no generics in the scheme data; meshbell has three or four messages).** Constraint: the scheme is `const` plain data; the `Row` trait is the only access path.
- **Card 2 — replaying `cases.txt` on the core.** Option A: the scheme is a `&[Field]` slice, so a host test builds it at runtime from the case text and replays every stage. Option B: generate Rust const schemes from `cases.txt`. **Chosen A (recommended: no generator, the hostile fixture stays the single source).** Constraint: `Field` is a plain struct, no const-generic type per scheme.
- **Card 3 — stack measurement.** Option A: link the Rust static library into the existing QEMU image (`startup.c`, `mps2.ld`, `stack_meter.hpp`) so Rust and C++ numbers are comparable. Option B: a Rust-only harness. **Chosen A (recommended: one measurement path).** Constraint: the Rust profile builds a `staticlib` with `panic = "abort"`; the harness owns the panic handler, and the link check proves decode does not reach it.
- **Card 4 — the second walker.** Option A: differential test over golden, text, ecc and hostile data (std pack equals core pack, std unpack equals core unpack) on every host run. Option B: rely on the shared vectors only. **Chosen A (recommended: the cost of two walkers is paid in tests).** Constraint: any format change must change both walkers in one task.

## Scenarios (Part B)

| id | scenario | status | behavior (confirmed) | AC ref |
|----|----------|--------|----------------------|--------|
| R1 | A relay seals a status report into a 64-byte buffer, no allocator | confirmed | `pack` returns the bytes equal to the std `pack` of the same values; `Result.offset` is the length | AC-1, AC-4 |
| R2 | The output buffer is too small | confirmed | `BufferFull` with the bytes needed; nothing is written past `cap` | AC-1 |
| R3 | Untrusted bytes: empty, short, trailing, a count above the limits | confirmed | `ShortPacket`, `TrailingBytes`, `TooMany`; never a panic or an out-of-range read | AC-2 |
| R4 | The hostile corpus (`fixtures/hostile/cases.txt`: construct, unpack, pack, limit stages) | confirmed | each case returns the refusal its row names (rows the C++ runner skips for a documented reason are skipped with the same reason) | AC-2 |
| R5 | A scheme invalid at construction (a `when` source above the id range, a duplicate name, an empty body) | confirmed | `validate` returns `SchemeInvalid` before any byte is read or written | AC-2 |
| R6 | A string longer than the scratch holds (`text` on) | confirmed | `ScratchTooSmall` naming the field with the words needed; no different encoding is written | AC-1 |
| R7 | `text` off, a scheme with a string | confirmed | a `Packed` member borrows the payload and forwards it unchanged; a string member is refused at validate (as `PACKBIN_NO_TEXT` does) | AC-3 |
| R8 | `ecc` off, a scheme with parity bytes | confirmed | refused at validate; parity 0 is the plain scheme | AC-3 |
| R9 | A protected message with wrong bytes (`ecc` on) | confirmed | repaired up to the limit; above it `Uncorrectable`; a message above 254 bytes `TooLong` | AC-1 |
| R10 | `session` on: seal and open with a caller nonce and no allocator | confirmed | same bytes as the std `PackSession` for the same seed and nonce | AC-1, AC-4 |
| R11 | Default features (`std`): the whole existing suite and the ring | confirmed | every row passes; wire bytes unchanged | AC-4 |
| R12 | A float with NaN bits, a 64-bit field on a 32-bit target, lengths near 65,535 | confirmed | bits preserved; sizes use checked arithmetic; the device image decodes the golden fixture under QEMU | AC-1, AC-2 |
| R13 | A build over the owner's size limits | confirmed | the CI job fails and prints the figure and the limit | AC-3 |
| R14 | Frame mode, the MAC-only call, hardware cycle counts, Swift frame mode | out-of-scope | meshbell PB-04, PB-10, PB-06b | — |

## Sizing

Estimate 13 as a feature (new subsystem, two unknowns: the stack measurement of a Rust image and the panic-path link check). The C++ core it follows is about 4,900 lines. Eight slices, each at most 5 points, 34 points in all: AZ-2749 features, core types, flat schemes and the host proof (5); AZ-2751 embedded profile CI (5); AZ-2752 flags, bits, u2, packed, sized, when (5); AZ-2753 repeat, group, times, lists, dicts (5); AZ-2754 compact text (5); AZ-2755 ECC (3); AZ-2756 session (3); AZ-2757 hostile corpus, differential proof, publish check, docs (3). The slices write one directory (`rust/src/nostd/**`) one after another, so they run in sequence, not in parallel; AZ-2751 and AZ-2752 need only AZ-2749 and may run in either order.
