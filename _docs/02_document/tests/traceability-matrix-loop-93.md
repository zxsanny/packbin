# Traceability matrix — loop 93 (AZ-3469)

Scenario FT-E-15 in `blackbox-tests-06-embedded.md`. Evidence: the `cpp-m33f` and `rust-m33f` rows (`scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`, 3 passed) and the failure runs in `_docs/03_implementation/batch_01_loop93_report.md`.

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3469 AC-1 | stack top 0x38020000 on 4 `cpp-m33f` and 5 `rust-m33f` images | Covered | FT-E-15 step 1; `check_ram_end` |
| AZ-3469 AC-2 | HEAD figures unchanged in the window | Covered | FT-E-15 step 1 |
| AZ-3469 AC-3 | a 130 KiB array fails the link and the row | Covered | FT-E-15 step 2 (scratch run) |
| AZ-3469 AC-4 | a 4 MB script fails both rows | Covered | FT-E-15 step 3 (scratch run) |
| AZ-3469 AC-5 | no other row moves, no row added | Covered | arm stage 6 of 6 PASS; `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh` |
| AZ-3469 AC-6 | words match | Covered | script header, `lib.sh`, `rust/embedded/README.md` |
