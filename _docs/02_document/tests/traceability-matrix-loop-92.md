# Traceability matrix — loop 92 (AZ-3452)

Scenario FT-E-14 in `blackbox-tests-06-embedded.md`. Evidence: the `cpp-avr-uno` row of the arm stage (`scripts/loop-tests.sh --only cpp-embedded-arm`, 6 of 6 rows PASS) and the failure runs in `_docs/03_implementation/batch_01_loop92_report.md`.

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3452 AC-1 | the image runs on `simavr` and reports `size_t` 2 and `int` 2 | Covered | FT-E-14 step 1; `avr/chacha20_check.cpp` |
| AZ-3452 AC-2 | RFC 8439 2.4.2 vector, 114 of 114 bytes | Covered | FT-E-14 step 1 (`RFC 114/114`) |
| AZ-3452 AC-3 | 9 lengths equal the `chacha20_block` stream and restore | Covered | FT-E-14 step 1 (`STREAM 9/9`, `RESTORED 9/9`) |
| AZ-3452 AC-4 | 32-bit counter edge, 5 cases | Covered | FT-E-14 step 1 (`EDGE 5/5`) |
| AZ-3452 AC-5 | the row fails on a changed byte, a defect, a hang, a missing or a silent `simavr` | Covered | FT-E-14 step 2 (five real-path runs, reverted) |
| AZ-3452 AC-6 | 0 warnings, Uno budgets, no change under `cpp/src` or `cpp/include` | Covered | the `cpp-avr-uno` row notes (image 3,798 B flash, 316 B RAM); `git diff --stat cpp/src cpp/include` empty |
| AZ-3452 AC-7 | the two stale sentences corrected | Covered | `README.md`, comment above `avr_arch` in `arm.sh` |
