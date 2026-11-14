---
kind: queue-item
order: 900
source: loop 126 findings, left over by loop 127
origin: agent
severity: low
depends_on: []
status: blocked
blocked_on: holds fewer than five entries (work-queue.md §Agent-made work)
created: 2026-11-14
---
# Hygiene

Minor agent-made items share this one loop. Ready when it holds five entries or when nothing else in the queue is ready.

## Entries

1. **Smaller debug frames in the deep-scheme walks** (loop 126, D19 option B; split out of loop 127 as not small): Swift `bindAll` (`swift/Sources/Packbin/References.swift`) and Rust `pack_one` / `unpack_one` use frames large enough that 256 nested levels overflow a debug build on a small thread (Swift 640 KiB, `flags` 1.5 MiB; Rust about 3 MiB). Evidence: `_docs/gotchas/deep-scheme-stack-by-build-and-thread.md`. Done when 256 levels of every kind run on a 512 KiB (Swift) and 2 MiB (Rust) debug thread with the device pins held.
2. **Contract: a typed element row** (loop 126 review; decision D20 in `_docs/OPERATOR_TODO.md`): C# counts a typed `list(row)` as one level (the element row group counts 0) but a map-form `list(group(...))` as two, as Java, Go and TypeScript do. Done when D20 is answered, `scheme-depth.md` Counting says it and C# is aligned.
