# Security review — the heap-free Rust API (loop 50, AZ-2749, AZ-2751)

**Date**: 2026-10-20 · **Scope**: `git diff 85a4714..HEAD` limited to `rust/src/nostd/**`, `rust/Cargo.toml`, `rust/src/lib.rs`, `rust/embedded/**`, the `embedded-arm` steps of `.github/workflows/test.yml`, the `rust-embedded` service of `docker-compose.test.yml` and `scripts/loop-tests.sh` · **Verdict**: PASS (no Critical, High, Medium or Low finding; three observations)

## Trust boundary

`nostd::unpack` and `nostd::Reader` read untrusted bytes in firmware that cannot catch a panic. Evidence that nothing on that path panics, allocates or loops on a claimed count:

- **Link check on a real image** (`rust/embedded/checks.sh`, target `rust-m4f`): the linked Cortex-M4F image holds no heap symbol and no panic symbol. The check found three panic paths in the first version (`copy_from_slice`, `slice::reverse`, a range index) that the clippy deny list did not; they are removed. Seeded defects (a table indexed by input, a `Vec` behind a malloc allocator) are caught (`rust-mutants`).
- **Lints**: the module denies `unwrap`, `expect`, `panic`, indexing and unchecked arithmetic; a probe of each was rejected.
- **Differential tests**: every cut, every extended and every retyped copy of a packet, and 30,000 random packets (5 layouts, 6,000 each, lengths 0 to 64), are accepted or refused alike by the map API and by `nostd`; accepted ones carry equal values.
- **No count-driven work**: this slice has no `times`, `repeat`, list or dictionary, so no count in a packet sets a loop bound or an allocation. Work is one pass over the scheme's fields. (Those kinds come in AZ-2753 with their limits; they need their own review.)
- **Integers**: lengths use `checked_add` and `get`; a `u16` field id is validated against its place; `usize` is 32 bits on the target and 64 on the host, both tested.

## Dependencies (Phase 1)

`packbin` and `packbin-probe` have no third-party crate (`Cargo.lock` lists only themselves), so there is nothing for `cargo audit` to match. The toolchain is pinned (`1.98` in CI, `1.79` on this Mac) and installed by `rustup` over HTTPS with its own hash check, like the `ring` job.

## Static analysis (Phase 2)

- `unsafe`: none in the crate. The probe has three `unsafe extern "C"` functions that build slices from the pointer and length the C harness passes; they are in `rust/embedded/probe`, excluded from the published package (`exclude = ["embedded/"]`, checked with `cargo package --list`).
- No secrets, no network access, no file access, no `unsafe impl`, no global state in `nostd`.

## Configuration and CI (Phase 4)

- The new `embedded-arm` steps run `rustup toolchain install` and `rustup target add` (no `curl | sh`), then `rust/embedded/run.sh host`; no secret is read, no token is passed, `cargo build --locked` is used.
- The `rust-embedded` compose service reuses the `packbin-embedded` image and mounts the checkout like `cpp-embedded` does; it needs no port and no extra privilege.
- `-Wl,--no-warn-execstack` is on the Rust links only; a Cortex-M image has no executable-stack notion and the flag changes no shipped artifact.

## Observations (not counted)

1. **O1**: the no-panic guarantee covers the library; a caller's `Row` methods run inside it and may panic. The rustdoc of `Row` does not say so yet; add a sentence (AZ-2757 docs).
2. **O2**: `pack_vec(limit)` allocates `limit` bytes before packing; a caller that took `limit` from a packet would let an attacker pick the allocation. The rustdoc now says `limit` is the caller's budget (fixed in this loop).
3. **O3**: the stack figures (88 B for a 14-field route) cover flat schemes; nested kinds change them; AZ-2753 and AZ-2754 report their own lines in `feature-sets.txt`.
