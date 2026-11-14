# Loop 127 smoke — hygiene (AZ-4306 to AZ-4308)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke127.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop127/smoke127.sh
```

## Checks

- [x] 1. application tree clean; stage stamps present, TypeScript and ring at the last code commit (`aad063b`)
- [x] 2. all nine probes: 60 lines, every one `refused`
- [x] 3. a 60-level diamond is refused by TypeScript in 0 ms (was 2^depth)
- [x] 4. the C# test file is 280 lines
- [x] 5. the seven new test files are present
- [x] 6. shellcheck clean on the probe scripts

## Agent walk

Run at `aad063b` plus the close artifacts: `smoke 127: 6/6 PASS`.

## For the operator

Nothing. D20 (typed element row) is open; D21 (keep the Rust nostd depth check) is an applied default.
