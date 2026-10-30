# Feature assessment - loop 84

FEATURE ASSESSMENT loop 84 round 1: COMPLETE - 14 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

Inputs: `scenarios.md` (14 rows), `batch_01_loop84_report.md` (`## Discovered during implementation`: 5 rows, all `clear`, all handled), the four specs' `### Excluded` lines, the review (PASS_WITH_WARNINGS, 4 Low, 0 bugs)

| # | Scenario | Status | AC | Test | Code path |
|---|----------|--------|----|------|-----------|
| 1 | "CI YAML reader" step deleted | covered | AZ-3390 AC-3 | mutant in `ring-wiring.test.sh`; scratch copy exit 0 -> 1, names `yaml_get.test.sh` | `ring-wiring-check.py` `scaffold_errors` |
| 2 | "CI workflow helpers" step deleted | covered | AZ-3390 AC-3 | mutant; names `workflow_yaml.test.sh` | same |
| 3 | `if` / `continue-on-error` on either step | covered | AZ-3390 AC-4 | 4 scratch copies, exit 1 (HEAD 0) | same |
| 4 | real `test.yml` | covered | AZ-3390 AC-2 | checker exit 0, three wiring tests pass | same |
| 5 | host build and tests | covered | AZ-3391 AC-2 | `loop-tests.sh` cpp stage PASS; worker `make test` gcc:16 `-Werror` | `Makefile` |
| 6 | a consumer lists only the old file | covered | AZ-3391 AC-3 | all 3 consumers read against the parts; every build links both parts (arm stage 6 rows, host); no deliberate-omission run | `arm.sh`, `Makefile`, `CMakeLists.txt` |
| 7 | ARM, ESP, big-endian stages | covered, ESP NOT RUN | AZ-3391 AC-5 | arm stage PASS in `loop-tests.sh` (M33F 25,760 B within the raised pin); s390x 315 of 315; ESP only read | `arm.sh`, ESP `CMakeLists.txt` |
| 8 | each part at 500 lines or below | covered | AZ-3391 AC-1 | `wc -l`: 314 and 246 | `cpp/embedded/common/` |
| 9 | header used by its part | covered | AZ-3392 AC-1 | use counts of all 13 includes | `handoff_ecc.cpp`, `handoff_frame.cpp` |
| 10 | 10 rows sorted ahead of the `id-padded` needle | covered | AZ-3392 AC-3 | scratch case file: HEAD test FAILS, changed passes, lying go driver still caught | `ring-frame.test.sh`, `ring_frame.py` |
| 11 | `kMax`, `frame_hex` | covered | AZ-3392 AC-4 | unchanged; probe recorded in the spec | `handoff_common.hpp` |
| 12 | literal `python-version: "3.14"` | covered | AZ-3393 AC-3 | mutant, exit 1 (HEAD 0) | `python_errors` |
| 13 | `RING_PYTHON` differs from compose image | covered | AZ-3393 AC-2 | mutant `3.13`, exit 1 | `suite_errors` |
| 14 | workers in one loop | covered | plan | paths compared with HEAD before copy-back; no git or Jira writes by workers | parent merge |

Not walked: none. Leftovers (not gaps of this feature): the ESP-IDF stage has not run on the new source list (CI first); a job-level `RING_PYTHON` override in a non-ring job is not compared with the compose image.
