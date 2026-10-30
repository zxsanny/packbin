# Expected results - loop 84

Input -> expected output pairs. Figures are HEAD a925aa7.

| # | Input (command) | Expected output |
|---|-----------------|-----------------|
| 1 | `python3 -I .github/workflows/ring-wiring-check.py <test.yml minus the "CI YAML reader" step> docker-compose.test.yml` | HEAD: exit 0 (the defect). After: exit 1, message names `scripts/ci/yaml_get.test.sh` |
| 2 | same with the "CI workflow helpers" step removed | HEAD: exit 0. After: exit 1, names `scripts/ci/workflow_yaml.test.sh` |
| 3 | `bash .github/workflows/ring-wiring.test.sh` | PASS with N+2 mutants (N on HEAD, read in the T1 spec) |
| 4 | `wc -l cpp/embedded/common/*.cpp` | every file <= 500 (HEAD: `all_kinds.cpp` 560) |
| 5 | `make -C cpp test` | same pass count as HEAD, 0 warnings under `-Wall -Wextra -Werror` |
| 6 | `bash .github/workflows/ring-frame.sh` after T3 | same pair counts and `0 mismatched` as HEAD |
| 7 | `bash .github/workflows/ring-frame.test.sh` with 10 extra rows sorted before the needle (scratch copy) | `id-padded` still PASS; go padding still FAILS it |
| 8 | `grep -c '3\.14' .github/workflows/test.yml` | HEAD: 3. After: 1 |
| 9 | wiring check on a copy with `python-version: "3.14"` in `scaffold` | HEAD: exit 0. After: exit 1 |
| 10 | wiring check on a copy with `RING_PYTHON: "3.13"` | exit 1 (compose says `python:3.14`) |
