---
title: "In the embedded Rust probe, do not return a large Session by value through a Result: load it in place"
applies_when: "the embedded Rust stage's stack figure moves, or the probe (pb_rs_extra) builds a session"
source: "loop 69 (Rust frame mode; the bullet names no loop, taken from git history)"
---

The embedded Rust stage reports the stack of the deepest call including every local of `pb_rs_extra`: a 590-byte `Session` returned by value and moved through a `Result` is three copies on the device stack (probe 2,968 B against 2,048 B); `Session::frame_unloaded()` plus `load_frame_in_place` keeps one (1,896 B).

Read frame sizes with `arm-none-eabi-objdump -d` (`sub sp, #N` of the function) when the figure moves.
