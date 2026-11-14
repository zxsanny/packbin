---
kind: queue-item
order: 900
source: loop 126 findings (AZ-4300, AZ-4302)
origin: agent
severity: low
depends_on: []
status: ready
blocked_on:
created: 2026-11-14
---
# Hygiene

Minor agent-made items share this one loop. Ready when it holds five entries or when nothing else in the queue is ready.

## Entries

1. **Smaller debug frames in the deep-scheme walks** (loop 126, D19 option B): Swift `bindAll` (`swift/Sources/Packbin/References.swift`) and Rust `pack_one` / `unpack_one` use frames large enough that 256 nested levels overflow a debug build on a small thread (Swift 640 KiB, `flags` 1.5 MiB; Rust about 3 MiB). Evidence: `_docs/gotchas/deep-scheme-stack-by-build-and-thread.md`. Done when 256 levels of every kind run on a 512 KiB (Swift) and 2 MiB (Rust) debug thread with the pins held.
2. **`csharp/tests/HostilePackVectorTests.cs` is 509 lines** (loop 126, AZ-4296; soft cap 500): split by responsibility.
3. **Rust: `times(...)` / `repeat(...)` constructors call `round_width`, which recurses over their members before `MapScheme::new`** (loop 126, AZ-4302): a huge `when` chain inside one `times` can overflow there, before the depth check. Move the check before it, or make `round_width` iterative.
4. **Depth walk re-visits a shared Field once per parent** (loop 126 review): only Java dedups (`IdentityHashMap`); C#, TypeScript, Go, Swift, Dart and Python walk a diamond-shaped scheme (the same Field reused twice per level) in time exponential in the depth before the 257-level stop. The older walks have the same shape. Probe it, then dedup the check or refuse shared fields.
5. **Contract: a typed element row** (loop 126 review): C# counts a typed `list(row)` as one level (the element row group counts 0) but a map-form `list(group(...))` as two, as Java, Go and TypeScript do. Decide and write it into `scheme-depth.md` Counting, then align C#.
6. **Dart flag byte `.bit` depth test** (loop 126 review): the fix that stopped counting `flagBit` as a level has no test of its own (the chain tests use `flags(0, [...])`); add 129 `flags` each holding a flag-byte bit at the boundary.
7. **Rust nostd depth check is quadratic in the container count** (loop 126 review, worker report): one descent per level-opening entry; measure a 32,768-entry table of containers and make it linear if it takes seconds.
8. **TypeScript `elementOf` re-measures the sub-chain on every `list()` / `dict()`** (quadratic, bounded by the 257-level stop) and **Python `_finish_round` imports inside the function**: tidy both.
9. **Walk-timing tests build 250 levels through the full build** (Go, Java, C#; AZ-4257 / AZ-4259 guards): the large chain stays on the walk alone; add a whole-build timing guard that fits the limit if a quadratic step is suspected.
