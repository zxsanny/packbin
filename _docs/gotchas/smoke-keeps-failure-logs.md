---
title: "A smoke script keeps its step logs on a failure, and its greps do not depend on one tool version's wording"
applies_when: "writing a smoke or test script that deletes its work directory or greps a tool's error text"
source: "loop 74 (one Go FAIL in eight runs, test name lost)"
---

A smoke script that deletes its work directory on exit loses the log of a failure that does not repeat (loop 74: one Go `FAIL` in eight runs, test name lost): keep the step logs on a failure (`smoke74.sh` copies them to `$TMPDIR/smoke74-failed-logs`).

A grep on a tool's error text must not depend on one version's wording (the host's default Cargo is 1.79, Docker's is 1.98) or on a file name that a contract shares with a removed command (`pack-session.md`).
