---
title: "Run the ESP core stage before a commit that adds or removes a C++ core or embedded/common source"
applies_when: "adding, removing or splitting a cpp/src/core/*.cpp or cpp/embedded/common source"
source: "loop 75 (frame.cpp, embedded-esp-core red 4 min after the push), loop 84 (all_kinds_rounds.cpp)"
---

A new C++ core source (`cpp/src/core/*.cpp`) changes the source count that `cpp/embedded/esp.sh` checks (`expected N packbin sources in the build`: 7 since loop 75, `frame.cpp`; 8 since loop 84, `cpp/embedded/common/all_kinds_rounds.cpp`: the count covers the `embedded/common` sources too, so splitting or adding one there moves it, and loop 84 failed `embedded-esp-core` on the close push for exactly that, 3 minutes after it); `scripts/loop-tests.sh` does not run the ESP stage, so CI job `embedded-esp-core` was the first to fail (loop 75, 4 min after the push).

Run `bash cpp/embedded/run.sh host esp core` (about 3 minutes, needs the ESP-IDF image) before the commit that adds or removes a core source, and list it in the C++ worker prompt.

A new core source also goes into `.github/workflows/ring-lib.sh`: see [frame-ring-run-before-push.md](frame-ring-run-before-push.md).
