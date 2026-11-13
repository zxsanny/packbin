# Loop 118 smoke — C# sets the bit of a flags inside a flags (AZ-4251); gotchas split

LOCAL_URL: none (a library; no site). The checklist is the script `smoke118.sh` beside this file.
Branch: dev

```bash
bash _docs/loops/loop118/smoke118.sh
```

## Checks

- [x] 1. C# `FlagsInFlagsTests` pass on `net10.0` and the `netstandard2.0` build (AC-1, AC-2, AC-3, AC-6)
- [x] 2. the nine-package probe prints 40 lines, all `same`; C# `both` packs `01030109` (AC-4, AC-5)
- [x] 3. the probe writes nothing into the checkout (AC-4)
- [x] 4. `shellcheck` clean on the probe scripts (NFR)
- [x] 5. the gotchas split: `_docs/AGENT_GOTCHAS.md` gone, 46 files and 46 index lines, no live reference left (bootstrap B2 migration)
- [x] 6. `_docs/00_problem/tracker.md` names the Jira site and connector

## Agent walk

Run at `1f19fb0` (the batch commit), host load 12, 36 s:

```
PASS  1. C# FlagsInFlagsTests pass on net10.0 and netstandard2.0 (17 passed each)
PASS  2. nine-package probe: 40 lines, all same; csharp both 01030109
PASS  3. the probe leaves the checkout clean
PASS  4. shellcheck clean on the probe scripts
PASS  5. gotchas split: 46 gotcha files, 46 index lines, no live reference
PASS  6. _docs/00_problem/tracker.md names the Jira site
smoke 118: 6/6 PASS
```

## For the operator

Nothing.
