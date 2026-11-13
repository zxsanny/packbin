---
title: "gh run list --commit needs the full 40-character SHA; a short SHA returns an empty list"
applies_when: "watching CI runs for a commit with gh"
source: "loop 114 (a CI watcher printed empty polls for 8 minutes)"
---

`gh run list --commit <sha>` matches only the full 40-character SHA: a short SHA returns an empty list, not an error (loop 114: a CI watcher printed empty polls for 8 minutes); pass `$(git rev-parse HEAD)` or watch by run id (`gh run view <id> --json status,conclusion`).
