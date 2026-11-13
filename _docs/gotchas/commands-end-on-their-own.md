---
title: "Every worker, reviewer or parent shell command ends on its own: stdin from /dev/null, no bare cat or read, a timeout"
applies_when: "running any shell command from a worker, a reviewer or the parent, or writing a file from the shell"
source: "loop 16 (a bare cat sat 2.5 hours), loop 92 (a parent cat > file, 2 minutes lost)"
---

A worker or reviewer command must end on its own: stdin from `/dev/null`, no bare `cat` or `read`, no unfinished here-doc, and a timeout on anything that can hang (macOS has no `timeout`: `perl -e 'alarm N; exec @ARGV' -- cmd`); in loop 16 a bare `cat` sat 2.5 hours and showed as a running task.

A parent shell command never starts with a bare `cat > file` (no here-doc): it waits on stdin until killed (loop 92, 2 minutes lost, the worker rule above repeated); write files with the Write tool or a quoted here-doc.
