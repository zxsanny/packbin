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
2. **Go: building nested groups is superlinear** (loop 127, AZ-4306 worker C): 62 groups take 0.2 ms, 125 take 3.3 ms, 250 take 29-35 ms, against 0.13 ms for 250 `when`s. `foreignNames` (`go/places.go:207-241`) copies the path at every level (`append(path[:len(path):len(path)], g)`) and runs for every group, about cubic. The Go groups timing guard is set at a nominal 150 ms so it stops growth only. Done when 250 groups build in about 1 ms and the guard bound is tightened.
3. **Shared nested rows (a diamond with no ids) are still exponential in the id walks** (loop 127, workers B and C): `checkFieldIDs` / `validateFieldIDs` restart ids per nested row and recurse per parent, so a diamond of shared `nested` / `group` rows is 2^depth in Dart, Swift and Go (and may be in TypeScript, Python, C#); the `when` diamond is fixed in loop 127 (depth check and the walks before the id check). Probe nine packages with a nested-row diamond, then memoise or refuse a Field used twice.

