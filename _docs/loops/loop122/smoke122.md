# Loop 122 smoke — hygiene (AZ-4277, AZ-4278)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke122.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop122/smoke122.sh
```

## Checks

- [x] 1. the application tree is the batch commit (`e25c8d6`)
- [x] 2. Dart repeat-last cost test passes 3 of 3 runs (best of three builds)
- [x] 3. a quadratic copy of the Dart walk fails that test (10,034 ms and 15,151 ms against 300 ms)
- [x] 4. `run-suite.test.sh` passes (C1: flag on, failing sanitizer build, flag off); `clang==19` pinned and allowed by the pins check
- [x] 5. the cpp suite in its container: plain tests, then ASan + UBSan with clang 19 under 600 s, green (sanitizer step 52 s, suite 137 s)
- [x] 6. a planted heap overflow fails the sanitizer build (`AddressSanitizer: heap-buffer-overflow`)
- [x] 7. `shellcheck -S warning` on the changed CI shell files: clean

## Agent walk

Run at `e25c8d6`, host load about 8, about 6 minutes: `smoke 122: 7/7 PASS`.

## For the operator

Nothing. The three green CI runs of AZ-4278 AC-1 are read by the agent after the push (this record, then the next loop record).
