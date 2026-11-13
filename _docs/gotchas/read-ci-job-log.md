---
title: "Read a red CI job's log before calling it a flake"
applies_when: "a CI job is red, or a CI-only failure needs its log"
source: "loop 49 (unproven flake), loop 53 (failed again), loop 54 (AZ-2815, fixed), loop 106 (log while the run is in progress)"
---

Read a red CI job's log before calling it a flake:

```
gh api repos/zxsanny/packbin/actions/jobs/<id>/logs --allow-escape-sequences | sed 's/\x1b\[[0-9;]*m//g'
```

(job ids from `gh api repos/zxsanny/packbin/actions/runs/<run>/jobs`). Loop 49 recorded the red C# suite on `main` as an unproven flake; the log showed the same speed test 2 to 8% over its 1 s bound, and it failed again in loop 53 (fixed in loop 54, AZ-2815).

Read a CI-only failure with `gh api --allow-escape-sequences repos/zxsanny/packbin/actions/jobs/<id>/logs` while the run is still in progress (`gh run view --log-failed` waits for the whole run; loop 106, see [buildkit-host-network-allow.md](buildkit-host-network-allow.md)).

Related: a red push that changed no workflow may be a runner image change ([ubuntu-latest-image-changes.md](ubuntu-latest-image-changes.md)); `gh run list --commit` needs the full SHA ([gh-run-list-full-sha.md](gh-run-list-full-sha.md)).
