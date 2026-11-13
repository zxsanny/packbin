---
title: "The heap-free Rust core never calls split_at_mut, rotate_left, copy_within, reverse, copy_from_slice or chunks*"
applies_when: "editing rust/src/nostd, ecc_core.rs or session_core/, or running rustfmt in rust/"
source: "loop 52 (link check failed), loop 53 (chunks_mut(64) at opt-level z)"
---

In `rust/src/nostd`, `ecc_core.rs` and `session_core/` (both under `rust/src/`) never call `split_at_mut`, `rotate_left`, `copy_within`, `reverse`, `copy_from_slice` or any `chunks*` (at opt-level z `chunks_mut(64)` links a div-by-zero and a `panic_fmt`, loop 53): they link a panic path that clippy does not see and the Cortex-M4F link check fails (loop 52); use `get_mut` ranges and zipped copies.

Run `rustfmt` on single files and `git checkout -- rust/src/walk/text_tables.rs` after it: the `#[path]` module makes rustfmt reformat that generated file.
