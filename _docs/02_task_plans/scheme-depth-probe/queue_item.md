---
kind: queue-item
order: 500
source: found in loop113 (AZ-4217 fix round)
origin: agent
severity: medium
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Dart: a very deep scheme overflows the stack when it is built

## Problem
A chain of 5,000 nested `when`s throws `Stack Overflow` when `scheme(...)` builds it, before and after the loop 113 check (the cause is not the repeat-last pass). A hand-written scheme is not untrusted input, but the other packages were probed in earlier loops for scheme depth (check what each does) and an uncaught `StackOverflowError` is not a `PackbinException` of kind `schemeError`.

## Outcome
Either the build refuses a scheme deeper than a stated limit with a `schemeError` (the limit and its text decided with the other packages), or the walks are made iterative; one decision for all nine packages.

## Code sections
`dart/lib/src/build.dart`, `dart/lib/src/checks.dart` (the recursive walks), and the matching scheme-depth rules of the other packages (search `depth`, `nested too deep`).

## Acceptance checks
- A probe builds a 5,000-deep and a 50,000-deep chain of `when`s (and of groups) in each package and prints build outcome and error type.
- The findings table shows the answer per package; any package that dies with a raw stack error gets a task, and the owner gets one decision for the class.

## Needs
none (an owner decision on the limit may follow the probe)

## Constraints
No packet changes.
