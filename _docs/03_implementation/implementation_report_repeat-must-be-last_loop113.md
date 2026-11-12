# Implementation report — repeat-must-be-last, loop 113

Epic AZ-4209; tasks AZ-4210 to AZ-4219 and AZ-4232 (32 points); contract `_docs/02_document/contracts/library/repeat-last.md` 1.0.2.

Every package refuses, when a scheme is built, a `repeat` that is not the last thing its packet reads: a field that can write a byte after it, a second repeat, a repeat inside a list or dict element, and (Java, C++, Dart in a nested row) a repeat inside a round. No packet changes: 0 bytes differ in the fixtures, the golden vectors and the ring (step 11, 15 of 15 stages, 24 min). The owner's decision of 2026-11-12 (loop 112): "Refuse at build".

- Batches: `batch_01_loop113_report.md` (AZ-4210), `batch_02_loop113_report.md` (the nine package tasks, the review fixes and AZ-4232); review `reviews/batch_01_loop113_review.md`; completeness `implementation_completeness_loop113_report.md`; assessment `_docs/loops/loop113/assessment113.md` (EXTEND in round 1, COMPLETE in round 2).
- Commits: `2c285d7` (claim), `d5d6874`, `e1e85d1`, `9239873`, `4927d4a`, `3b548f3`, `888a3e8`.
- Library source: 27 files, 1,012 lines; tests and loaders: 86 files, 6,858 lines; device cost: Rust heap-free pins +104 to +112 B of flash, C++ pins unchanged.
- Left: the vcpkg checks (NOT RUN), queue items for the C# `flags` in `flags` defect, Dart's deep scheme, the Dart timing helper in one more test, the ESP core pin; owner rows N1, N2, N4 and D4 to D7 in `_docs/OPERATOR_TODO.md`.
