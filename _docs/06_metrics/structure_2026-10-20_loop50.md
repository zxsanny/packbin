# Structure snapshot — 2026-10-20, loop 50

Source: `_docs/02_document/module-layout.md`, `rust/src/nostd/**`, `rust/embedded/**`.

| Metric | Loop 46 | Loop 50 |
|--------|--------:|--------:|
| Components | 8 | 8 |
| Cross-component import edges | 0 (packages are peers) | 0 |
| Cycles | 0 | 0 |
| New modules | | `rust/src/nostd` (6 files, 588 lines), `rust/embedded` (probe crate, stage scripts) |
| Architecture findings (new / resolved) | 0 / 0 | 0 / 0 |
| Contracts | unchanged | unchanged (the wire format did not change) |

The Rust package now holds two walkers (map API and `nostd`) over one wire format; `nostd_differential_tests.rs` is the guard.
