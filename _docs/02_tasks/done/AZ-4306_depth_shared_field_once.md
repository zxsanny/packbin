---
loop: 127
branch: dev
---

# Depth check: a Field shared by two parents is measured once (TypeScript, Python, Dart, Swift, C#, Go)

**Task**: AZ-4306_depth_shared_field_once
**Name**: Depth check: a Field shared by two parents is measured once
**Description**: The six depth checks that walk the scheme as a tree get Java's rule: a field already measured at an equal or greater depth is not walked again.
**Complexity**: 3 points
**Dependencies**: AZ-4294 to AZ-4303 (done, loop 126)
**Component**: typescript, python, dart, swift, csharp, go
**Tracker**: AZ-4306
**Epic**: AZ-4133

## Problem

The 256-level check (contract `scheme-depth.md`) runs first and walks fields as a tree. A Field used twice per level (the same object in two places) is walked once per parent: a scheme of D such levels costs 2^D steps before the stop. The field-id check would refuse such a scheme at once, but the depth check runs before it. Measured: TypeScript, `when` whose members are the next level twice, 17 ms at 20 levels, doubling per level; 40 levels would take hours. Java dedups with an identity map (`SchemeOrder.checkDepth`).

## Outcome

- In each of the six packages the depth walk keeps the greatest depth at which each node was reached (identity map or set) and does not walk a node again unless it is reached deeper than before (Java's rule). A scheme without shared fields measures exactly as before.
- A diamond of 60 levels is answered within one second: refused by the package's id rule, or by the depth rule, never a hang.

## Scope

### Included
- The depth check of each package and its tests. Owns: the six package folders only.
### Excluded
- Java (already done); Rust and C++ (flat tables, no shared nodes); the other walks; the contract.

## Acceptance Criteria

**AC-1: A diamond is answered quickly**
Given a scheme whose each of 60 levels holds the next level's field twice (the same object)
When it is built
Then it fails within one second with the package's scheme error (any text), no hang, no stack error

**AC-2: Depth unchanged**
Given the loop 126 depth tests of the package
When they run
Then they pass unchanged (256 builds, 257 is refused, every kind)

**AC-3: Deeper reuse is still measured**
Given a field reached first at a shallow depth and again deeper (a 255-level chain plus a shared leaf also placed at the bottom of a longer path)
When the scheme is built
Then the depth is that of the deepest path (257 refused)

## Constraints
Memory is O(nodes). No new public name. Each refusal test is proved against the old behaviour once (switch the dedup off by hand).

## Flagged concerns
none
