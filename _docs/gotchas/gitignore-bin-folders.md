---
title: "A new folder named bin is ignored by **/bin/: check git status --ignored and un-ignore it"
applies_when: "adding files under a folder named bin (a driver's bin/)"
source: "loop 99 (Dart driver bin/handoff_dart.dart)"
---

`.gitignore` has `**/bin/`: a new folder named `bin` (a Dart driver's `bin/handoff_dart.dart`, loop 99) is ignored and its files are never committed, so the Mac run is green and CI says "file not found".

After adding files run `git status --short --ignored <folder>` and un-ignore with a `!path/bin/` line, as for `.github/workflows/drivers/handoff-dart/bin/`.
