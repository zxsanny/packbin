# Loop 124 smoke — run-suite split (AZ-4288)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke124.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop124/smoke124.sh
```

## Checks

- [x] 1. tree is the batch commit (`935deaa`); step 11 stamps (11 stages) at it or later
- [x] 2. `run-suite.sh` 397 lines (under 400), `run-suite.test.sh` 485 (within 500)
- [x] 3. the moved helpers are word for word the removed lines (102 lines)
- [x] 4. `run-suite.test.sh` and `report-row.test.sh` pass
- [x] 5. a copy without `run-suite-cpp.sh` / `-go.sh` / `-rust.sh` fails the self-test (4 / 19 / 21 failures)
- [x] 6. `shellcheck -S warning` clean

## Agent walk

Run at `935deaa`: `smoke 124: 6/6 PASS`.

## For the operator

Nothing.
