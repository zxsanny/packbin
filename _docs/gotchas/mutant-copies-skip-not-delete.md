---
title: "Build a mutant copy by copying every file except the one under test; never rm from a variable path"
applies_when: "writing a mutant or missing-file check that copies scripts into a scratch folder (RUN_SUITE_SH, smoke scripts)"
source: "loop 124 (AZ-4288)"
---

Claude Code's built-in removal check refuses `rm` or `rm -rf` on a path built from a variable it cannot resolve (`rm -rf "$S"`, `rm "$S/run-suite-go.sh"` with `S=$(mktemp -d …)`), even in the scratchpad, and only a person can approve it. A mutant that needs a file missing is built without a removal: `for f in .github/workflows/*.sh …; do [ "$(basename "$f")" = run-suite-go.sh ] || cp "$f" "$dir/"; done`, in a fresh `mktemp -d` folder per mutant (`_docs/loops/loop124/smoke124.sh` step 5).
