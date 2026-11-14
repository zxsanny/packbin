---
loop: 125
branch: dev
---

# Loop 125 — Probe how deep a scheme may be in all nine packages

Loop 125 (on `dev`; no worktree). Intake: the queue item `dart-deep-when-chain-stack-overflow` (`queue_item.md` beside this file; found in loop 113), picked from the backlog because the operator decision D9 was applied at option A on 2026-11-14 (probe all nine first).

## What and why

A Dart scheme of 5,000 nested `when`s throws a raw `Stack Overflow` when it is built, not a `schemeError`. Nobody has measured what the other eight packages do with a very deep scheme (nested `when`s, nested groups, nested lists of rows). After this loop there is one committed probe per package and one findings table: per package and depth, does the build succeed, is it refused with the package's own error, or does it die with a raw stack error; and does a pack and unpack of a packet that fits the deep scheme work.

Not in this loop: a depth limit or any change to a package (the owner decides the class after the table; a package that dies with a raw stack error gets a task, not a fix here), the width of a scheme, depth of the packet (values) rather than of the scheme.

## Code sections

Probes go under `scripts/probes/scheme-depth/` (new, the layout of `scripts/probes/element-row/`: `run.sh`, one folder per package, `README.md`); the findings under `_docs/06_metrics/scheme-depth-probe_2026-11-14.md`. Package source is read only: `dart/lib/src/build.dart`, `dart/lib/src/checks.dart` and the build of each other package (search `depth`, `nested too deep`).

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| A probe that overflows the stack must not take the probe run down: each depth runs in its own process, and a crash is printed as `threw` / `crashed` | agent | open | Low |
