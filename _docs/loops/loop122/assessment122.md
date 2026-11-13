# Feature assessment — loop 122 (AZ-4277, AZ-4278)

round: 1
verdict: COMPLETE — 9 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| Dart cost test: best of three builds against the load-aware 300 ms bound | AZ-4277 AC-1 | `repeat_last_cost_test.dart` `_bestBuild`; 3 of 3 alone | covered |
| a quadratic walk still fails it | AZ-4277 AC-2 | scratch copy of `checks.dart` with an uncached `_followers`: 10,272 ms and 14,698 ms vs 300 ms | covered |
| passes in the pool beside the other suites | AZ-4277 AC-3 | step 11 pool run (`--jobs 4`) | covered (step 11) |
| the sanitizer build runs in CI on every `test.yml` push, with its own 10-minute limit | AZ-4278 AC-1 | `run-suite.sh cpp` step under `timeout 600`, compose `cpp` sets `PACKBIN_CPP_SANITIZER=1`, CI entry `cpp typescript java`; self-test C1; mutant without the limit caught | covered (three green CI runs: loop close and the next loop record) |
| a memory error fails it | AZ-4278 AC-2 | planted heap overflow in a scratch copy: `AddressSanitizer: heap-buffer-overflow`, exit 2 | covered |
| a failing sanitizer build fails the suite with a FAIL row | AZ-4278 | self-test C1 (`FAKE_FAIL_ON`); mutant "flag ignored" caught | covered |
| workflow checkers still pass (20-job limit, nine-name suites matrix) | AZ-4278 AC-3 | no `test.yml` change; scaffold and publish-gate stages of step 11 | covered (step 11) |
| clang major from `tool-pins.txt`, not the runner | AZ-4278 AC-4 | `tool-pin.sh clang` read in `run-suite.sh`; self-test checks `clang-19` from the pin; missing pin prints a reason | covered |
| the plain `make -C cpp test` stays first and unchanged; no job without the flag runs the sanitizer | AZ-4278 constraints | self-test C1 (first line `make -C … test`; flag off: no apt-get, no sanitizer-test) | covered |
| a user's own clang build of a `when` with 255+ members fails at `table.hpp:266` (fold nesting limit) | discovered | only the sanitizer build has `-fbracket-depth=512` | out-of-scope (hygiene entry, Low) |
| `clang-19` disappears when `gcc:16` moves off Debian trixie | discovered | the pin comment; apt fails loudly naming the package | out-of-scope (hygiene entry, Low) |

Discoveries read: `batch_01_loop122_report.md` (three rows: the 20-job design change, handled in the spec; two Low entries carried to the hygiene item).
