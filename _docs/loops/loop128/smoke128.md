# Loop 128 smoke — C# typed element row counts two levels (AZ-4314)

LOCAL_URL: none (a library). The checklist is the script `smoke128.sh` beside this file.

```bash
bash _docs/loops/loop128/smoke128.sh
```

## Checks

- [x] 1. application tree clean; csharp, ring and ac10 stamps at the batch commit (`62c658f`)
- [x] 2. the C# probe: six lines, all `refused`
- [x] 3. the contract states the rule (1.0.3)
- [x] 4. the D20 test exists and the element row counts one level
- [x] 5. D20 recorded as decided

## Agent walk

Run at `62c658f` plus the smoke script: `smoke 128: 5/5 PASS`.

## For the operator

Nothing.
