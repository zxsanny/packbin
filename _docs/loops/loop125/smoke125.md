# Loop 125 smoke — scheme depth probe (AZ-4291)

LOCAL_URL: none (probes and documents; no site). The checklist is the script `smoke125.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop125/smoke125.sh
```

## Checks

- [x] 1. application tree clean; step 11 `scaffold` stamp at the batch commit (`c76f445`) or later
- [x] 2. no package source changed (AC-5): 0 files
- [x] 3. six fast packages (typescript, python, cpp, dart, csharp, java) run twice: 35 identical lines (java `group-5000` excluded: edge of the limit), nothing written (AC-1, AC-4)
- [x] 4. findings table: 60 rows, nine packages (AC-3)
- [x] 5. `shellcheck -S warning` and `bash -n` clean
- [x] 6. a crash, a timeout and an exit are one line each (AC-2)

## Agent walk

Run at `c76f445`: `smoke 125: 6/6 PASS`. The full nine-package run (60 lines, 303 s, exit 0) was done once at HEAD `97c3fcf` plus the probe files, before the batch commit; the smoke repeats the six fast packages.

## For the operator

Nothing.
