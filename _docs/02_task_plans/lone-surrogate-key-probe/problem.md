---
loop: 102
branch: dev
---

# Loop 102 — Probe the six other packages for the unreadable colliding-key packet

Loop 102 (on `dev`; no worktree). Intake: the owner's "Yes, probe them" (2026-11-11) to the question "Probe the other six packages for the same unreadable packet?", the open item of `_docs/loops/loop101/record101.md`.

## What and why

TypeScript (until loop 101) wrote a packet its own unpack refused for two dictionary keys that differ only in unpaired UTF-16 surrogates, because each lone half is written as U+FFFD. TypeScript and Dart now refuse it at pack. Whether C#, Java, Python, Go, Rust and Swift write the same kind of packet was never measured. This loop measures it: it changes no package code. The result is a table (package, can a lone surrogate be given as a key, what `pack` does, whether the package's own unpack reads what it wrote), and a list of follow-up tasks for the owner to choose from.

Scope: one probe per package, run on HEAD ec86364 with that package's toolchain; the dictionary scheme with a `u8` value; the cases `{"\ud800": 1, "\udc00": 2}` (two lone halves), `{"�": 1, "\ud800": 2}` (a real U+FFFD and a lone half) and, for languages whose encoder writes another replacement (Java `?`), the key that equals the replacement. A language whose strings cannot hold a lone surrogate (Rust, Swift) is recorded from its type, plus a probe with the nearest invalid input if the API allows one.

Not in scope: changing any package, any release, the text field (not a key) of the same packages (recorded when the probe shows it).

## Code sections / UI locations for this loop

Owner (2026-11-11): the dictionary key pack of the six packages C#, Java, Python, Go, Rust and Swift (the question named them). To be found by `git grep` in each package (`csharp/`, `java/`, `python/`, `go/`, `rust/`, `swift/`): the code that writes a dictionary's keys and the code that writes a text.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| the probes run each package's own toolchain; a toolchain that fails here (the Mac needs Docker for Go) must be reported, not replaced by a reading of the code | meta-rule: real results | open | Low |
