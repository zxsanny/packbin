---
kind: queue-item
order: 500
source: found in loop113 (security audit F79, `_docs/05_security/security_report_loop113.md`)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Java, C# and Go: the repeat-last walk is quadratic on a deep chain of containers

## Problem
`SchemeOrder.repeatLast` (Java), `RoundScopes.CheckLast` (C#) and `checkRepeatLast` (Go) call `firstWriter` at each level while a repeat is open, so a chain of nested `when` or group containers costs O(depth squared): Java 438 ms at depth 8,000 (9 ms at 1,000), C# 336 ms (13 ms before the rule). Both fail on the stack before the depth gets much larger, so the cost stays under a second. TypeScript, Dart and Swift were changed to one pass in loop 113; Python, Rust and C++ were linear. The schemes are code, not wire input.

## Outcome
The three walks memoize the first writer (or carry the open repeat forward in one pass, as Swift and Dart do), so the walk is linear for any shape; every decision and refusal text stays the same.

## Code sections
`java/src/main/java/packbin/SchemeOrder.java`, `csharp/RoundScopes.cs`, `go/counted.go`; tests in each package with the package's load-aware timing helper.

## Acceptance checks
- A scheme with a chain of 4,000 nested `when`s (and one with 16,000 sibling `when`s that write nothing) builds in time linear in its size in each of the three packages (a timing test with the load helper that fails on the old walk).
- A differential over random trees gives the same decisions and texts as before.
- The three package suites pass.

## Needs
none

## Constraints
No packet change; the shared hostile cases and every refusal text stay unchanged.
