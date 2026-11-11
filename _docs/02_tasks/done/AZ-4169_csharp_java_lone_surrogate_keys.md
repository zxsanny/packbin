---
loop: 103
branch: dev
---

# C# and Java: refuse dictionary keys that collide after U+FFFD; Java writes U+FFFD

**Task**: AZ-4169_csharp_java_lone_surrogate_keys
**Name**: C# and Java: refuse dictionary keys that collide after U+FFFD; Java writes U+FFFD (loop 103)
**Description**: C# and Java refuse a dictionary whose keys become one key once an unpaired surrogate is written as U+FFFD, and Java writes U+FFFD (not "?") for a lone surrogate.
**Complexity**: 5 points
**Dependencies**: AZ-4153, AZ-4168 (the Dart and TypeScript rules)
**Component**: csharp, java
**Tracker**: AZ-4169
**Epic**: AZ-4133

## Problem

Loop 102 showed that C# and Java write a packet their own unpack refuses when two dictionary keys differ only in unpaired surrogates, and that Java writes a question mark for a lone surrogate where TypeScript, Dart and C# write U+FFFD. The owner chose (2026-11-11, option A) that both packages refuse the collision at pack as TypeScript and Dart do, and that Java writes U+FFFD. Pack files: `_docs/02_task_plans/csharp-java-lone-surrogate-keys/` (`problem.md`, `acceptance_criteria.md` CJ-1 to CJ-7, `scenarios.md`, `input_data/expected_results/results_report.md`).

## Outcome

- No package of the five that can hold a lone surrogate (TypeScript, Dart, C#, Java, Python) writes a dictionary packet its own unpack refuses.
- A caller gets a clear error naming the dictionary instead of a packet the reader refuses.
- A lone surrogate is written the same way (U+FFFD) in TypeScript, Dart, C# and Java.

## Scope

### Included
- C#: refuse the collision at pack (`ArgumentException`), tests, no other byte changes.
- Java: write U+FFFD for an unpaired surrogate in a key and a text, refuse the collision at pack (`IllegalArgumentException`), tests.
- Tests that read the 16 TypeScript packets and the 7 report cases in each package, and a seeded random check in each.
- Docs that say the open C# and Java item: README notes, the loop 102 findings, the C# and Java component docs.

### Excluded
- Python, Go, Rust, Swift, TypeScript, Dart.
- Any release or version change (NuGet and Maven Central stay at 0.4.0).
- A rule for text fields beyond a lone surrogate.

## Acceptance Criteria

**AC-1: C# refuses (CJ-1)**
Given the 4 colliding dictionaries
When packed in C#
Then an `ArgumentException` naming the dictionary is thrown and no bytes are returned.

**AC-2: C# unchanged (CJ-2)**
Given the dictionaries without a collision and a text with a lone half
When packed in C#
Then the bytes equal today's and all existing C# tests pass.

**AC-3: Java refuses (CJ-3)**
Given the 4 colliding dictionaries
When packed in Java
Then an `IllegalArgumentException` naming the dictionary is thrown and no bytes are returned.

**AC-4: Java writes U+FFFD (CJ-4)**
Given a text or key with an unpaired surrogate in the bare, raw and compact forms
When packed in Java
Then the bytes equal TypeScript's, `{"?", "\ud800"}` packs to `01020002103f010410efbfbd02`, and no packet holds a `?` written for a lone half.

**AC-5: Never unreadable (CJ-5)**
Given 20,000 seeded random dictionaries in each package
When packed and unpacked
Then every returned packet unpacks to the swapped keys and every refusal is a real collision (0 unreadable packets in C#, 0 in Java).

**AC-6: Four packages agree (CJ-6)**
Given the 5,000 seeded dictionaries of loop 101 and the 7 cases of its report
When packed by C#, Java, TypeScript and Dart
Then all refuse the same dictionaries and write the same bytes for the rest (0 disagreements).

**AC-7: Docs (CJ-7)**
Given the change is complete
When the documents outside dated history are read
Then none says C# or Java writes an unreadable packet for colliding keys.

## Non-Functional Requirements

**Performance**
- Java encodes each key once for the sort and the write (not once per comparison); the common case (no lone surrogate) costs one scan of the string.

**Compatibility**
- C#: no byte changes except that a colliding dictionary now throws. Java: only text or keys with a lone surrogate change (`3F` becomes `EF BF BD`). Android: the Java code uses no API newer than the package already uses.

**Reliability**
- Unpack is unchanged in both packages.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the 4 colliding dictionaries in C#, one as a list element | `ArgumentException` with the field name; nothing written |
| AC-2 | the 5 unchanged packets in C# | the hex of the results report |
| AC-3 | the 4 colliding dictionaries in Java | `IllegalArgumentException` with `dict: ...`; nothing written |
| AC-4 | the 16 TypeScript packets, `{"?", "\ud800"}`, a text with a lone half | the hex of TypeScript's packets and the report |
| AC-5 | 20,000 seeded dictionaries per package | every returned packet unpacks; every refusal collides |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | the 5,000 seeded dictionaries and the 7 report cases | C#, Java, TypeScript and Dart agree | 0 disagreements | Compatibility |
| AC-2, AC-4 | the existing C# and Java suites and shared fixtures | unchanged | all pass | Compatibility |

## Constraints

- Messages follow each package's existing style (C#: `<field>: reason`; Java: `dict: reason`) and the TypeScript and Dart wording.
- Java: no API newer than what `java/` already needs on Android; the sort uses precomputed bytes.

## Risks & Mitigation

**Risk 1: Java byte changes for a lone surrogate**
- *Risk*: a caller relied on the `?` the old code wrote.
- *Mitigation*: the owner chose it; the old packet merged keys and read back "?" for a different character; both packages are unreleased with the change.

**Risk 2: a missed encoder call in Java**
- *Risk*: a third `getBytes` path keeps writing `?`.
- *Mitigation*: `git grep getBytes java/src/main` lists the three call sites; AC-4 covers keys and texts in all three forms.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| a colliding dictionary now throws in C# and Java | owner chose it (2026-11-11) | accepted-risk | Low |
| Java writes U+FFFD where it wrote "?" | owner chose it (2026-11-11) | accepted-risk | Low |
