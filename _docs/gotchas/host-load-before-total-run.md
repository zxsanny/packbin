---
title: "A total scripts/loop-tests.sh run at host load above 60 is not a result: check the load first"
applies_when: "starting a total scripts/loop-tests.sh run, or reading its failures"
source: "loop 71 (two hours at load 112)"
---

A total `scripts/loop-tests.sh` run at host load above 60 is not a result: loop 71's ran two hours at load 112 (an unrelated `tippecanoe` job of another session, 318% CPU) and three publish-gate shares failed on swift-crypto cache directories and downloads.

Check `ps -Ao pcpu,command -r | head` and `uptime` first, stop your own run (`pkill -f loop-tests.sh`, `publish-gate.test.sh`, remove `packbin-publish-*` containers) and rerun the failed stage alone at a lower load.
