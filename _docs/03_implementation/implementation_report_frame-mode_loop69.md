# Implementation report — frame mode, Rust first (loop 69)

Epic AZ-3199, umbrella AZ-3192. Five tasks, 19 points, four batches (`80999ef`, `06206b1`, `3d9b3f9`, `af39b7f`) and a gap-close commit.

- AZ-3200 contract 2.0.0 and ADR-008. AZ-3201 primitive vectors (Python and Rust). AZ-3202 frame golden vectors (170 rows). AZ-3203 Rust frame mode. AZ-3204 embedded `frame` set.
- Device (Cortex-M4F, QEMU): `frame` 19,772 B flash, 1,896 B stack, 0 B RAM; the four existing sets identical to the commit before.
- Per-batch review was not run (owner preference: one total review and one step 11 run per loop). Reports: `batch_0{1..4}_loop69_report.md`, completeness `implementation_completeness_loop69_report.md`, assessment `_docs/loops/loop69/assessment69.md`.
- Added beyond the spec's shape: `Session::frame_unloaded`, `Session::load_frame_in_place` (stack), `ReplayWindow::from_parts`/`parts` (restoring a window), `stream_hits` in the embedded checks.
