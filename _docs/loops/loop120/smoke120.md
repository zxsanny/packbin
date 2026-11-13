# Loop 120 smoke — Java refuses a setter that rejects the unpack collection (AZ-4255)

LOCAL_URL: none (a library; no site). The checklist is the script `smoke120.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop120/smoke120.sh
```

## Checks

- [x] 1. Java suite green with `CollectionTypeTest` (AC-1 to AC-4)
- [x] 2. element-row probe: `coll-linkedlist` and `coll-treemap` refused at unpack by the package (AC-5)
- [x] 3. 22 probe lines, no `threw:` left, pack hex of those two lines equals the `ArrayList` and `HashMap` lines (AC-5)
- [x] 4. README Java bullet

## Agent walk

Run at `51a33ff`, host load 12, 16 s: `smoke 120: 4/4 PASS`.

## For the operator

Nothing.
