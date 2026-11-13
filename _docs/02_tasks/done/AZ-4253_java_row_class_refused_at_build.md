---
loop: 119
branch: dev
---

# Java: refuse at build an element-row or nested-row member declared for another row class

**Task**: AZ-4253_java_row_class_refused_at_build
**Name**: Java: refuse at build an element-row or nested-row member declared for another row class
**Description**: A nested row with a child factory (the element row of a list or dict, or a nested row) checks at construction that its members' accessors take its row class; a member declared for another class is refused with the package's error.
**Complexity**: 3 points
**Dependencies**: AZ-4242 (done)
**Component**: `java/src/main/java/packbin/` (`Field.java`, a new package-private check), `java/src/test/`, `README.md` Java section
**Tracker**: AZ-4253
**Epic**: AZ-4133

Queue item `java-element-row-raw-class-cast` (loop 116 probe note 5), owner decision D10 A (refuse at build), mechanism D13 A (applied). Problem: `_docs/02_task_plans/java-element-row-raw-class-cast/problem.md`.

## Problem

A member declared for another row class inside an element row or a nested row builds; pack then throws a raw `ClassCastException` (`Comment cannot be cast to Other`). C# (AZ-4205), Go and Swift refuse it at build. Java accessors are erased lambdas, so the declared class cannot be read; the group's child factory can make a row to call them on.

## Acceptance Criteria

**AC-1: Refused at build, element row**
Given a list (or dict) whose element is `group(identity, ignore, Comment::new, members declared for Other)`
When the scheme is built
Then it throws `IllegalArgumentException` whose message names the member (kind and id) and the row class `Comment`; no `ClassCastException` escapes.

**AC-2: Refused at build, nested row**
Given `group(get, set, Comment::new, members declared for Other)` as a member of a typed row
When the scheme is built
Then the same refusal.

**AC-3: Through the containers that share the row**
Given such a member under a `when`, a `flags` bit, an anchored group or a `times` round of the nested row
When the scheme is built
Then the same refusal.

**AC-4: Base class**
Given members declared for a base class of the row class
When the scheme is built, packed and unpacked
Then it builds and round-trips with the same bytes as members declared for the row class.

**AC-5: Not a class mismatch**
Given a member whose getter throws another exception on a fresh, empty child (for example a `NullPointerException` from a field that is null until set)
When the scheme is built
Then it builds as before (the getter's failure is reported by pack when it happens there).

**AC-6: Nothing else changes**
Given the Java suite, the fixtures, the golden vectors and `bash scripts/probes/element-row/run.sh java`
When they run
Then the suite passes, no byte differs, and only the probe lines `other-row` and `nested-other-row` change, from `threw:` to `refused:`.

**AC-7: README**
The README Java section says a member declared for another row class is refused when the scheme is built, and that each member's accessors run once on a fresh child from the factory then.

## Tests

| AC | test | kind |
|----|------|------|
| AC-1 to AC-5 | `java/src/test/java/packbin/RowClassTest.java` (new) | unit |
| AC-6 | step 11 `java` stage, ring; the probe run at close | suite, probe |
| AC-7 | review | doc |

## Constraints

- No API change; no package other than Java.
- A member whose accessors take `Object` (a hand-written `Getter`) cannot be told apart and builds as before.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| User accessors run once at build on an empty child (a getter with side effects runs one more time) | D13 A, applied | accepted-risk | Low |
