---
title: "Read every figure an AC or estimate names from a run on HEAD in the same loop"
applies_when: "writing an acceptance criterion or estimate that names a count, bytes of flash or bytes of stack"
source: "loops 60, 62 and 63"
---

Every figure an AC or an estimate names (a count, bytes of flash, bytes of stack) is read from a run on HEAD in the same loop, with the log line pasted into `problem.md`; never the previous loop's table and never a per-entry multiplication.

Loop 60 (`grep -c .` gave 34, the rule 33), loop 62 (table estimate 56 B, measured 224 B; AC-1 28 B relaxed to 32 B), loop 63 (AC-3 stack 412 / 448 / 500 B, HEAD 404 / 440 / 492 B).
