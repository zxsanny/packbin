# Loop 121 smoke — hygiene (AZ-4257 to AZ-4261)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke121.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop121/smoke121.sh
```

## Checks

- [x] 1. step 11 stage stamps (10 stages) at the batch commit or later
- [x] 2. Java element-row probe: 22 lines, no raw exception, missing member named (`missing utf8 1` typed, `missing text` Map)
- [x] 3. Python element-row probe: `null-member` and `null-item` refused
- [x] 4. Dart: no fixed bound left, analyzer and format clean
- [x] 5. C++ stub tests (s390x percentage compare, ESP core pin)
- [x] 6. ESP core pinned at 3.3.12 and its gotcha indexed
- [x] 7. shellcheck: `lib.test.sh` and `publish-pins.test.sh` clean, no finding added to the sourced fragments `arm.sh` and `examples.sh`
- [x] 8. four README bullets

## Agent walk

Run at `88df315`, host load 12, 11 s: `smoke 121: 8/8 PASS`. (A first run failed step 7: my bar was stricter than the project's, and two new SC2016 notes in `lib.test.sh` were real. Both fixed, then re-run, plus the three stages that file selects.)

## For the operator

Nothing.
