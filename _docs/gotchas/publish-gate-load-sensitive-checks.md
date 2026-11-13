---
title: "Rerun a failed publish-gate share alone at low load before calling it a regression"
applies_when: "a publish-gate share fails in scripts/loop-tests.sh, or the host load is high before the gate"
source: "loop 65 (host load 9 to 22), loop 66 (gt_window and ph_quote fixes)"
---

The full `scripts/loop-tests.sh` publish-gate runs 8 shares at once and two checks are load-sensitive (loop 65, host load 9 to 22):

- `publish-go.test.sh` AC-3 (`PACKBIN_GO_PROXY_WINDOW=3`: `the proxy was asked once only: 1`) failed in two of two parallel runs,
- and `publish-phases-failures.test.sh` AZ-2096 AC-4 (a `pip install` in the container returned 1, its own error is not kept in the log) in one;

each passed alone (`bash .github/workflows/publish-gate.test.sh --groups go` 28 s, `--groups phases` 325 s, the 11 groups of share 7 alone 1,057 s).

Read the share log, then rerun that share alone before calling it a regression; wait for load below 6 before the gate:

```
env PATH=<dir with python3 -> /opt/homebrew/bin/python3.14>:$PATH PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" bash .github/workflows/publish-gate.test.sh --groups <list>
```

(Since loop 100 the Python for the gate is `python3.13`, see [mac-host-recipes.md](mac-host-recipes.md).)

A Monitor that ends on `grep -q '^EXIT '` also ends on the script's own line `EXIT traps of the sourced check files`: match `^EXIT [0-9]+$`.

Loop 66 fixed the Go window (`gt_window` in `publish-go.test.sh`: 3 s plus four times the slowest probe ask) and made the phases tests quote 25 lines (`ph_quote`); the full gate then passed at host load 6 to 37 (378 s). The cause of the one container `pip install` failure is still unknown: if it shows again, read the quoted lines before adding a retry to `publish-inside.sh`.
