---
title: "Do not retry a pack-side held_of for flash or stack: it costs flash and saves no pack stack"
applies_when: "refactoring the C++ pack side when / flag bit decision (pack_children, pack_one)"
source: "loop 61 (AZ-3167), measured again in loop 63"
---

A pack-side `held_of` (one function for the `when` / flag bit decision, asked by `pack_children` and `pack_one`, as in `unpack.cpp`) costs **+44 to +72 B** of Cortex-M4F flash in every shape tried (8,076 to 8,104 B against the pin of 8,032 B) and saves 0 to 8 B of pack stack, which is not the limiting side (loop 61; table and patch in `_docs/02_tasks/done/AZ-3167.md` (the file is `_docs/02_tasks/done/AZ-3167_cpp_pack_held_of_measure.md`) and `_docs/loops/loop61/pack_held_of_a.patch`).

Loop 63 found that saving (84 B, see the flash line) and measured it again on top: shape D (shared `held_of`, `pack_children` unchanged for flag bits) +44 B (7,768 B), shape A (the loop 61 patch) +72 B (7,796 B), and no pack-stack gain any more (404 B / 440 B / 492 B before and after, the 8 B of loop 61 went with `Field::count`); not kept. Retry only for a reason other than flash or stack.

(The Cortex-M4F rows these figures were measured on went in loop 94; see [cpp-m33f-row.md](cpp-m33f-row.md).)
