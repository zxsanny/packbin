# Loop 119 smoke — Java refuses a member of another row class at build (AZ-4253)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke119.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop119/smoke119.sh
```

## Checks

- [x] 1. Java suite green with `RowClassTest` (AC-1 to AC-6)
- [x] 2. element-row probe: `other-row` and `nested-other-row` refused by the package, naming the member and the row class (AC-1, AC-2)
- [x] 3. no other Java probe line changed: 22 lines, the only raw exceptions left are `coll-linkedlist` and `coll-treemap` (D12, next queue item) (AC-6)
- [x] 4. README Java bullet (AC-7)
- [x] 5. mechanism decision D13 recorded as applied

## Agent walk

Run at `352ae3d`, host load 14, 17 s: `smoke 119: 5/5 PASS`.

## For the operator

Nothing.
