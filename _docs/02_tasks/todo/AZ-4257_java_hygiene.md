---
loop: 121
branch: dev
---

# Java hygiene: linear repeat-last walk, missing member named, top-level row class refused at build

**Task**: AZ-4257_java_hygiene
**Name**: Java hygiene: linear repeat-last walk, missing member named, top-level row class refused at build
**Description**: entries of the hygiene queue item `_docs/02_task_plans/hygiene-loop121/queue_item.md` (loop 121), below; their text is the spec.
**Complexity**: 3 points
**Dependencies**: none
**Component**: java/ (SchemeOrder.java, VarFields.java, Scheme.java, RowClassCheck.java, tests, README)
**Tracker**: AZ-4257
**Epic**: AZ-4133

Java parts only. Decision D14 (applied): the top-level check makes one row with the no-argument constructor that unpack already uses (BinaryPacker `Cannot create`); a class without one builds as before; the check is the same accessor probe as RowClassCheck.

Each entry below: its Problem, Outcome, Code sections and Acceptance checks are this task's; an acceptance check that names another package belongs to that package's task. Common: no packet change, every refusal text of a path the entry does not name stays the same, the package suite passes.

## Entry: Java, C# and Go: the repeat-last walk is quadratic on a deep chain of containers

slug `walk-first-writer-memo-java-csharp-go`; severity low; source: found in loop113 (security audit F79, `_docs/05_security/security_report_loop113.md`); created 2026-11-12
### Problem
`SchemeOrder.repeatLast` (Java), `RoundScopes.CheckLast` (C#) and `checkRepeatLast` (Go) call `firstWriter` at each level while a repeat is open, so a chain of nested `when` or group containers costs O(depth squared): Java 438 ms at depth 8,000 (9 ms at 1,000), C# 336 ms (13 ms before the rule). Both fail on the stack before the depth gets much larger, so the cost stays under a second. TypeScript, Dart and Swift were changed to one pass in loop 113; Python, Rust and C++ were linear. The schemes are code, not wire input.

### Outcome
The three walks memoize the first writer (or carry the open repeat forward in one pass, as Swift and Dart do), so the walk is linear for any shape; every decision and refusal text stays the same.

### Code sections
`java/src/main/java/packbin/SchemeOrder.java`, `csharp/RoundScopes.cs`, `go/counted.go`; tests in each package with the package's load-aware timing helper.

### Acceptance checks
- A scheme with a chain of 4,000 nested `when`s (and one with 16,000 sibling `when`s that write nothing) builds in time linear in its size in each of the three packages (a timing test with the load helper that fails on the old walk).
- A differential over random trees gives the same decisions and texts as before.
- The three package suites pass.

### Needs
none

### Constraints
No packet change; the shared hostile cases and every refusal text stay unchanged.

## Entry: Java and Python: a missing required member is named by its name, not its id

slug `missing-member-message-by-name-java-python`; severity medium; source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 7); created 2026-11-12
### Problem
A row whose required `utf8 text` (id 1) is missing is refused by Java with `1: expected string` and by Python with `1: expected str`; TypeScript, Go and Swift say `missing text`. The id alone does not tell a scheme author which member is missing in a row of several.

### Outcome
Java and Python refuse a missing (null / absent) required member with a message that names the member, as TypeScript, Go and Swift do; a present value of the wrong type keeps its current message.

### Code sections
Java `VarFields.java` (the string getter), the matching paths for other kinds; Python `_pack.py` (the `expected str` check and its siblings); both packages' tests that pin the old text (grep them first).

### Acceptance checks
- Java and Python probe line `null-member` prints a refusal that contains `missing text`.
- A wrong-type value (an int for `text`) keeps its current message.
- Every test or fixture that pins the old text is updated in the same change; both suites pass.

### Needs
none

## Entry: Java: a top-level typed row member declared for another class still throws at pack

slug `java-top-level-row-class`; severity medium; source: found in loop 119 (review of AZ-4253); created 2026-11-13

### Problem
AZ-4253 refuses at build a member of another row class inside a nested row or an element row, using the group's child factory. A top-level `new Scheme<>(1, Row.class, ...)` has no factory, so a member declared for `Other` still builds and pack throws a raw `ClassCastException`. C# refuses it at build (`'Q' is declared for row type Other, but this scheme is for R`).

### Outcome
The top-level case is refused at build too, or the README says why it cannot be (no instance to call the accessors on).

### Code sections
`java/src/main/java/packbin/Scheme.java` (the constructor has `Class<T> type`), `RowClassCheck.java`.

### Acceptance checks
- A top-level member of another class is refused at build with the AZ-4253 text, or the README states the limit.
- Open point for the operator if it needs one: create the row with its no-argument constructor by reflection (fails for a class without one).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| agent-found hygiene entries; no operator decision outstanding (D14, D15 applied) | agent | accepted-risk | Low |
