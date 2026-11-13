---
title: "Write no file in the repository while the publish-gate stage of scripts/loop-tests.sh runs"
applies_when: "running scripts/loop-tests.sh (its publish-gate stage, about 10 minutes)"
source: "loop 31"
---

`scripts/loop-tests.sh` fails its `publish-gate` stage when anything in the repository changes while the shares run (a tree manifest before and after, loop 31): edit and write no file in the repo from the start of that stage to its end (about 10 minutes); keep notes in the scratchpad and commit them after.
