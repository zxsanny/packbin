# Loop 123 smoke — hygiene (AZ-4279, AZ-4280)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke123.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop123/smoke123.sh
```

## Checks

- [x] 1. tree is the batch commit (`5894c2c`); step 11 stamps (7 stages) at it or later
- [x] 2. a 300-field scheme with Debian clang 19: the old headers are refused (`fold expression with 300 arguments exceeded expression nesting limit of 256`), the new headers build and validate it
- [x] 3. no `-fbracket-depth` in `cpp/Makefile`; the m33f pins are unchanged
- [x] 4. `run-suite.test.sh`: a failed clang install names the pin and the Debian release
- [x] 5. lint clean; `run-suite.sh` at 500 lines

## Agent walk

Run at `5894c2c`, host load about 9: `smoke 123: 5/5 PASS`.

## For the operator

Nothing.
