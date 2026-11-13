---
title: "A new README Swift block needs a snippet in ReadmeExampleTests.swift or the test's filter; run the Swift suite after a docs task"
applies_when: "adding or changing a Swift (or frame-mode) example in a README"
source: "loop 71 (readme_swiftBlocks_areTheSnippets, 5 blocks against 4 snippets)"
---

A README Swift block that is not one of the snippets of `swift/Tests/PackbinTests/ReadmeExampleTests.swift` breaks `readme_swiftBlocks_areTheSnippets` (5 blocks against 4 snippets, loop 71): a new README Swift example needs the test's filter (it skips the `FrameSession.load(` block) or a snippet there; the worker's run came before the README edit, so run the Swift suite after the docs task.

Frame-mode examples of all three managed packages are checked by `scripts/frame/readme-examples.sh` against the `// README-BEGIN` / `// README-END` regions of their example tests.
