---
kind: queue-item
order: 900
source: loop 126 findings (AZ-4300, AZ-4302)
origin: agent
severity: low
depends_on: []
status: blocked
blocked_on: holds fewer than five entries and other items are not all done (work-queue.md §Agent-made work)
created: 2026-11-14
---
# Hygiene

Minor agent-made items share this one loop. Ready when it holds five entries or when nothing else in the queue is ready.

## Entries

1. **Smaller debug frames in the deep-scheme walks** (loop 126, D19 option B): Swift `bindAll` (`swift/Sources/Packbin/References.swift`) and Rust `pack_one` / `unpack_one` use frames large enough that 256 nested levels overflow a debug build on a small thread (Swift 640 KiB, `flags` 1.5 MiB; Rust about 3 MiB). Evidence: `_docs/gotchas/deep-scheme-stack-by-build-and-thread.md`. Done when 256 levels of every kind run on a 512 KiB (Swift) and 2 MiB (Rust) debug thread with the pins held.
2. **`csharp/tests/HostilePackVectorTests.cs` is 509 lines** (loop 126, AZ-4296; soft cap 500): split by responsibility.
3. **Rust: `times(...)` / `repeat(...)` constructors call `round_width`, which recurses over their members before `MapScheme::new`** (loop 126, AZ-4302): a huge `when` chain inside one `times` can overflow there, before the depth check. Move the check before it, or make `round_width` iterative.
