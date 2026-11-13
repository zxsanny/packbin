# Feature assessment — loop 123 (AZ-4279, AZ-4280)

round: 1
verdict: COMPLETE — 7 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| a `when` of 300 members builds with clang 19 at default limits | AZ-4279 AC-1 | cpp suite in `gcc:16`, sanitizer build without `-fbracket-depth` (54 s, green); `table.hpp` `total()`, `nest()` | covered |
| a scheme of 300 top-level fields builds with clang 19 | AZ-4279 AC-2 | `az4279_scheme_of_300_top_level_fields_builds`; a 300-field file fails on the old headers (`fold expression with 300 arguments`) and compiles on the new | covered |
| the row-class check still refuses a member of another row | AZ-4279 | `binds_all` keeps the `static_assert` text; compile-fail tests in `make -C cpp test` | covered |
| no run-time cost (flash, stack) | AZ-4279 AC-3 | step 11 `cpp-embedded-arm`: m33f flash 25,948 B and stack 740 B, both equal to the pins | covered |
| a failed clang install names the pin and the Debian release, and fails | AZ-4280 AC-1 | `cpp_clang_install`; self-test with a failing fake `apt-get` | covered |
| the line is absent after a good install; no sanitizer build after a failed one | AZ-4280 AC-2 | self-test C1; a mutant without the line is caught | covered |
| folds over a handful of schemes (`pack_any`, `unpack(on(...))`) and type lists | AZ-4279 constraints | left as folds: their packs are not member lists | covered (by constraint) |
| `run-suite.sh` at the 500-line cap | discovered | next change there splits the cpp/Go helpers out | out-of-scope (noted in the batch report and the retro) |

Discoveries read: `batch_01_loop123_report.md` (one row).
