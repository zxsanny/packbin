# Handoff to loop 50

From the loop 49 record (`record49.md`). Nothing here is owner-decided yet.

## Candidates

| Row | Work | Owns |
|-----|------|------|
| Rust no_std core | `_docs/02_tasks/todo/AZ-2749_rust_nostd_core.md`: 5 points, Rust package builds without std and alloc for Cortex-M4F (meshbell); the spec says epic pending and needs the Complexity Budget A/B/C before code | `rust/` (core, features, embedded CI) |
| Compact memo | C++ repeated text that compacts still parses each round; only if real messages repeat long texts | `cpp/src/core/text_encode.hpp` (flash margin 272 B, stack 8 B: arm embedded stage) |
| Retrospective | Last retro `retro_2026-10-20_loop46.md`; due by loop 51 | `_docs/06_metrics` |

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Read after the push

- `test.yml` on `dev` and `main` for the loop 49 push (loop 48: wall about 220 s, longest job `embedded-esp-core` 204 s).
