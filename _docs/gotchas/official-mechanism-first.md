---
title: "Read the language's own documentation and use its official tool before writing or keeping a security or test mechanism"
applies_when: "writing or keeping a security or test mechanism (access for tests, key wipes)"
source: "loop 72 (Swift package), loop 73 (Rust write_volatile)"
---

Before writing or keeping a security or test mechanism, read the language's own documentation for its guarantee and use the official tool (loop 72: Swift `package`, not `@_spi` or `@testable`; loop 73: Rust `write_volatile` plus `compiler_fence` through `session_core/wipe.rs`, not `core::hint::black_box`, which Rust calls best effort); name the mechanism in the spec.
