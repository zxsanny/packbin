---
title: "A Go program ignores the SIGALRM of `perl -e 'alarm'`: give a Go case its own `timeout` inside the container"
applies_when: "running a Go binary under case.sh or any alarm-based time limit"
source: "loop 125 (scheme-depth probe: a group-50000 case hung over 4 minutes and the container had to be killed)"
---

`perl -e 'alarm N; exec @ARGV'` (the macOS stand-in for `timeout`, `commands-end-on-their-own.md`) ends a process with SIGALRM. A Go program ignores that signal, so a case that hangs runs on past the limit (loop 125: 4 minutes, then `docker kill`). Run a Go case as `case.sh go <shape> 60 timeout 55 <binary> ...` inside the `golang:1.27` container; the hang then prints `crashed: exit 124`, not `crashed: timeout`.
