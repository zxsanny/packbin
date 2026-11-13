---
title: "Keep the Mac awake for long runs, and read stage durations only from a run without a sleep"
applies_when: "starting a long run, a total scripts/loop-tests.sh, a smoke run or background subagents on this Mac"
source: "loop 20 (setsid, symlinked output, sleep, network drop), loop 74 (wall time across a laptop sleep)"
---

## Mac traps for long runs (loop 20)

Long runs on this Mac: `setsid` does not exist (launch the script as a harness background task), a subagent's output file is a symlink (`stat -L` in a heartbeat), monitors and `perl -e alarm` count wall time across laptop sleep (re-arm, or wait on one single-shot until-loop), and a network drop kills subagents (`ENOTFOUND`; resume them with SendMessage) and large downloads (`unexpected EOF` in the ESP Arduino target: re-run the stage).

## Laptop sleep inflates durations (loop 74)

A total `scripts/loop-tests.sh` or smoke run across a laptop sleep prints wall time (loop 74: swift 7,489 s, ring 3,525 s, both passed in about 10 minutes and 70 s): ask the app to keep the Mac awake first (`request_keep_awake`, `session_idle`), and read stage durations only from a run without a sleep.
