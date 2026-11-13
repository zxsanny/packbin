---
title: "Run the frame ring for real before any push that touches it; ring-frame.test.sh proves the script only"
applies_when: "changing the frame ring, its drivers, ring-lib.sh, or adding a cpp/src/core source"
source: "loop 77 (AZ-3338, frame.cpp missing from ring-lib.sh), loop 79 (stale drivers, git archive copies)"
---

The frame ring (loop 77, AZ-3338) is run for real before any push that touches it: `bash .github/workflows/ring-frame.sh` takes about 15 s with the drivers built (python3.14 first on `PATH`, `PACKBIN_CXX_SYSROOT`), and `ring-frame.test.sh` uses stand-in drivers, so it proves the script only. (Since loop 100 the Mac's Python with PyYAML is `python3.13`, see [mac-host-recipes.md](mac-host-recipes.md).)

- The C++ driver links the core sources listed in `.github/workflows/ring-lib.sh` (a new `cpp/src/core/*.cpp` goes there too; `frame.cpp` was missing and CI failed to link).
- A scratch copy of the repo (`git archive HEAD`) needs a symlink to `typescript/node_modules` to run the TypeScript driver.
- Swift 6 on Linux refuses `stderr` (a global var): drivers use the `fail` helper of `Text.swift`; check a Swift driver change with `docker run swift:6.3.3 swift build -c release --static-swift-stdlib` as `ring-swift.sh` does.
- `run_lang` rebuilds the C# and C++ drivers only when the binary is missing, so a kept `PACKBIN_RING_WORK` runs the old drivers after a driver edit: use a fresh dir (loop 79).
- A `git archive` scratch copy for a driver run needs its root named `packbin` (the Swift package identity) and its own `PACKBIN_JAVA_HANDOFF`, `PACKBIN_GO_HANDOFF` and `PACKBIN_SWIFT_RING` (the default `/tmp` builds are newer than the archive's file times, so the copy would run the new drivers; loop 79).
