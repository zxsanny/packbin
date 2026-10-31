# Implementation report — parity percentage (loop 97)

Plan: `_docs/loops/loop97/plan97.md`; problem and criteria: `_docs/02_task_plans/parity-percent/`.

| Batch | Commit | Tasks | Points |
|-------|--------|-------|--------|
| 1 | cb49455 | AZ-3499 reference, vectors, contract, ADR | 3 |
| 2 | e99e5fe | AZ-3500 Python, AZ-3501 TypeScript, AZ-3502 C#, AZ-3503 Java | 12 |
| 3 | dad23bd | AZ-3504 Go, AZ-3505 Swift, AZ-3506 Rust, AZ-3507 C++ | 16 |
| 4 | 13cf468 | AZ-3508 ring and eight drivers | 5 |
| 5 | c350d1d | AZ-3509 docs | 3 |
| fix | 433ed19 | AZ-3507 file split under 500 lines | — |

Batch reports: `batch_01_loop97_report.md` to `batch_05_loop97_report.md`. Completeness: `implementation_completeness_loop97_report.md`.

Decisions taken during implementation (all recorded in the batch reports): percentage 0 is exactly a scheme without parity; the new vector rows live in `fixtures/ecc/percent-vectors.txt` so the eight old loaders stay as they are; last setter wins between a percentage and a count; the ring drives the 13-byte position message, so the largest-message rows are covered by vectors and package tests; Cortex-M33F pins raised by +188 B / +16 B (C++) and +376 B / +8 B (Rust `ecc`), inside the 400 B / 64 B allowance.

Tracker: AZ-3499 to AZ-3509 In Testing (read back from each transition result).
