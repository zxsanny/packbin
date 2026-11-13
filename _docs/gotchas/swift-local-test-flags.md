---
title: "Use plain swift test with Xcode selected; add the -F and rpath flags only when xcode-select points at Command Line Tools"
applies_when: "running swift build or swift test on this Mac"
source: "loop 26 (Swift package, Command Line Tools recipe), loop 55 (Xcode selected, Swift 6.4)"
---

Since loop 55 `xcode-select -p` is `/Applications/Xcode.app/Contents/Developer` (Swift 6.4) and a plain `swift test` works; the flags below break it (`module 'Testing' has no member named '__SourceBounds'`), so use them only when `xcode-select -p` is `/Library/Developer/CommandLineTools`.

Swift on a Mac with Command Line Tools only (no XCTest, `Testing` not found by default): the tests use swift-testing, and every local `swift test` appends

```
-Xswiftc -F -Xswiftc $F -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L
```

with `F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks` and `L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib` (else `no such module 'Testing'`, then `lib_TestingInterop.dylib` not found); one run of 48 tests takes about 11 s, the thread-sanitizer run 41 s.

Only one `swift build`/`swift test` at a time in the root tree (SwiftPM locks `.build`).
