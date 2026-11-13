---
title: "A Monitor or tail -f pipeline ends in grep --line-buffered or an until-loop on ^EXIT [0-9]+$, never cut, head or sort"
applies_when: "writing a Monitor or watcher on a log (step 11, the publish gate, a smoke run)"
source: "loop 31 (watcher ended in cut), loop 65 (EXIT match), loop 71 (the gate finished unseen again)"
---

A Monitor or `tail -f` pipeline ends in `grep --line-buffered` (or `sed -u`), never in `cut`, `head` or `sort`: in loop 31 the step 11 watcher ended in `cut -c1-260`, delivered nothing for 30 minutes and expired while the run finished; an expiry with no events is a broken watcher, so read the log file by hand (the long-jobs rule names this failure, repeated).

A Monitor on a log must end on `grep --line-buffered` or `until grep -q '^EXIT'`, never `cut` or `sed -u | cut` (the gate finished unseen again in loop 71).

A Monitor that ends on `grep -q '^EXIT '` also ends on the script's own line `EXIT traps of the sourced check files`: match `^EXIT [0-9]+$` (loop 65, see [publish-gate-load-sensitive-checks.md](publish-gate-load-sensitive-checks.md)).
