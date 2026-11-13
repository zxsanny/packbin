---
title: "On macOS use sed -i '' -e, never sed -i -e"
applies_when: "editing files in place with sed on this Mac"
source: "loop 99 (five stray *-e files)"
---

On macOS `sed -i -e '...' file` treats `-e` as the backup suffix and leaves `file-e` files (loop 99, five stray files): use `sed -i '' -e ...`, python or the Edit tool, and check `git status` for `*-e`.
