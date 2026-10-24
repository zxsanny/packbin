# Expected results — publish gate under load

| # | Input | Expected |
|---|-------|----------|
| 1 | `publish-go.test.sh`, `go` stub sleeping 5 s per call, window 3 s | exit 0; "never" case asks >= 2 |
| 2 | same test, `proxy_check` copy that breaks after one try | exit != 0, message "asked once only" |
| 3 | pip stub exits 1 printing `ERROR: stub pip failed`, python publish in `publish-phases-failures.test.sh` | build log holds `ERROR: stub pip failed` |
| 4 | `publish-gate.test.sh --groups go` / `--groups phases`, quiet host | exit 0, <= 60 s / <= 400 s |

Project rows exercised: none of `_docs/00_problem/` product ACs (this loop touches test support only).
