# Loop 126 smoke — scheme depth limit (AZ-4294 to AZ-4303)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke126.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop126/smoke126.sh
```

## Checks

- [x] 1. application tree clean; step 11 stamps present, Dart at the last code commit (`10ba849`)
- [x] 2. all nine probes: 60 lines, every one `refused` at 1,000, 5,000 and 50,000 levels
- [x] 3. hostile case file checks pass (`check-cases.sh`, `cases.test.sh`)
- [x] 4. the four shared cases and their sections; contract 1.0.2 with the counting rule
- [x] 5. `shellcheck -S warning` clean; `RUST_MIN_STACK` set for the Rust suite
- [x] 6. each package has its depth test file (10 files)

## Agent walk

Run at `10ba849` plus the close artifacts: `smoke 126: 6/6 PASS`.

## For the operator

Nothing. D19 (debug builds on small threads) is an applied default, open to B or C in `_docs/OPERATOR_TODO.md`.
