---
loop: 86
branch: dev
---

# Rust lib clippy cleanup (loop 86)

Source: `_docs/loops/loop85/handoff86.md` (candidate "`session_core` clippy"), probed on HEAD 02ffcef on 2026-10-30. The owner chose "Probe handoff candidates", then "Spec the clippy cleanup". No UI.

## Problem

`cargo clippy --lib --features text,ecc,frame` in `rust/` reports 11 warnings on HEAD (toolchain 1.97.1). The handoff named `session_core`; it has none. The warnings are in other modules:

| Lint | Where |
|------|-------|
| `int_plus_one` | `src/walk/text/encode.rs:237` |
| `unnecessary_map_or` (2) | `src/walk/text/encode.rs:270`, `:276` |
| `needless_range_loop` | `src/walk/text.rs:157` |
| `replace_box` | `src/field/mod.rs:268` |
| `type_complexity` (4) | `src/scheme/bound.rs:12`, `:13`, `src/scheme/mod.rs:19`, `:20` |
| `redundant_closure` | `src/scheme/mod.rs:145` |
| `duplicate_mod` | `src/nostd/text/mod.rs:18` (the table file `walk/text_tables.rs` is shared by `#[path]` on purpose, so the std and no_std text coders cannot drift) |

No CI job runs clippy, so the count only grows. This loop does not add a job (one new primitive for a hygiene fix); it brings the lib to 0 warnings.

Probed and dropped again (loop 85 reasons stand): the AVR `chacha20_xor` check (emulator), the Go window floor (conditional), `item` pointer removal (it is the `&mut T` the volatile write needs, no defect), ring driver for `nostd`, 128 KiB image, cycle timing.

## Change location

No UI. Verbal: the Rust library `rust/src`, the files in the table above. `field`, `scheme` and `walk` are `std`-only; `nostd/text/mod.rs` gets an attribute, no code, so no embedded image moves.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A rewrite changes behavior of a coder (`encode.rs` tie-break, `field` big-endian wrap) | AC-2 (Rust suite and ring unchanged) | open | Low |
| `is_none_or` needs Rust 1.82; no MSRV is pinned, CI uses 1.97+ (`RING_RUST`) and 1.98 (embedded) | none stated | open | Low |
