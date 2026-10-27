---
loop: 76
branch: dev
---

# Docs: the Swift DocC lists the frame types, and the vcpkg Windows reason is the live one

**Task**: AZ-3332_docs_swift_docc_vcpkg_reason
**Name**: Swift DocC "Public names" with the 10 frame types; ADR-003 and the C++ description without the `os_random` reason
**Description**: Two documentation corrections left by loops 74 and 75.
**Complexity**: 2 points
**Dependencies**: None
**Component**: 08_swift_package and 05_cpp_package (documentation only)
**Tracker**: AZ-3332
**Epic**: AZ-2645

Items 4 and 5 of `_docs/02_task_plans/hygiene-after-frame-ports/problem.md`.

## Problem

The Swift DocC catalog says "The whole API is listed here" and names none of the 10 public frame types (`FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `Freshness`, `ReplayWindow`, `MacKey`). ADR-003 line 48 and `05_cpp_package/description.md` line 136 give `os_random` (deleted in loop 74) as a reason the vcpkg port is Linux and macOS only; the live reason, which the README already states, is that the core is built and tested only with gcc on Linux and clang on macOS. The `"supports": "linux | osx"` line itself stays: dropping it would claim Windows without a Windows build, which is an owner decision.

## Outcome

- A Swift reader finds the frame API in the DocC list, with each type's public members as declared in `swift/Sources/Packbin/`.
- The two docs state the live reason only.

## Scope

### Included
- `swift/Sources/Packbin/Packbin.docc/Packbin.md` ("Public names"), `_docs/02_document/adr/003_cpp-vcpkg-git-registry.md` line 48 (a factual correction with the loop number), `_docs/02_document/components/05_cpp_package/description.md` line 136 (and line 17 only if it states the same reason).

### Excluded
- `.github/workflows/publish-embedded.sh` and `publish-vcpkg.test.sh` (the `supports` line and its check), `README.md` (lines 27 and 469 are already right; the README Swift snippet test must not be disturbed), any Swift source, a Windows build.

## Acceptance Criteria

**AC-1: Frame types listed**
Given `Packbin.md`
When it is searched for each of the 10 public frame types
Then all 10 appear in the "Public names" list with their public members, each member checked against its declaration in `swift/Sources/Packbin/FrameSession.swift`, `FrameTypes.swift` and `MacKey.swift` (0 of 10 today)

**AC-2: Swift suite unchanged**
Given the Swift suite
When it runs after the change
Then it passes with the same test count as `HEAD` of this loop

**AC-3: The stale reason is gone**
Given ADR-003 line 48 and the C++ description line 136
When they are read
Then neither names `os_random` as a reason for the Windows limit; both say the core is built and tested only with gcc on Linux and clang on macOS

**AC-4: The line and its check are unchanged**
Given the diff of this task
When it is read
Then `publish-embedded.sh`, `publish-vcpkg.test.sh` and `README.md` are not in it

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `grep -c` of the 10 names in `Packbin.md` | 10 of 10; every listed member exists in the source |
| AC-3 | `grep os_random` on the two lines | 0 as a reason |
| AC-4 | `git diff --stat` | the three files absent |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | Swift 6.4 on the Mac (`xcode-select -p` is Xcode) | the Swift suite | PASS, count equal | — |

## Constraints

- Only one `swift build` or `swift test` at a time in the root tree (SwiftPM locks `.build`); the parent runs it. The DocC text keeps the style of the list around it (one bullet per type, backticked members).

## Risks & Mitigation

**Risk 1: a listed member drifts from the source**
- *Risk*: the DocC list names a member that is not public.
- *Mitigation*: AC-1 checks each member against its declaration.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Should the port drop `supports` and claim Windows? | owner; needs a Windows build and test first | open (owner) | Low |
