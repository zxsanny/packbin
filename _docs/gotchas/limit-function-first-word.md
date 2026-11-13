---
title: "Call a time-limit shell function as the first word (limit 900 env VAR=1 cmd), never env VAR=1 limit ..."
applies_when: "writing a smoke or test script that puts a time limit on a command with environment variables"
source: "loop 71 (smoke step 2), loop 76 (smoke76 steps 3 and 7), loop 77 (smoke77 step 4)"
---

A smoke or test script runs a time limit through a shell function as the first word (`limit 900 env VAR=1 cmd`), never `env VAR=1 limit ...` (`env` cannot call a function; loop 71 smoke step 2 failed on it; repeated in loop 76: `env MSBUILDDISABLENODEREUSE=1 limit 600 dotnet ...` gave `env: limit: No such file or directory`, steps 3 and 7 of the first smoke76 trial failed on it; again in loop 77, step 4 of the first smoke77 trial exited 127).
