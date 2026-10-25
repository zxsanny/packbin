---
loop: 71
branch: dev
---

# Frame mode docs for C#, Java, Swift

**Task**: AZ-3235_frame_mode_docs_csharp_java_swift
**Name**: README examples, component descriptions, module layout and contract note for frame mode in three packages
**Description**: The documents tell a C#, Java or Swift developer how to use frame mode, with examples a test runs.
**Complexity**: 2 points
**Dependencies**: AZ-3232_csharp_frame_mode, AZ-3233_java_frame_mode, AZ-3234_swift_frame_mode
**Component**: documentation (README, `_docs/02_document/`)
**Tracker**: AZ-3235
**Epic**: AZ-3199

## Problem

README "Frame session" has only a Rust subsection; the three component descriptions and `module-layout.md` do not list the frame API; the contract names Rust as the only package.

## Outcome

- README "Frame session" gains `### C#`, `### Java` and `### Swift` subsections whose example code is the code of the example test in each package; the bold uniqueness rule stays; the Rust sentence "Rust is the first package" names the four packages.
- Components `01_csharp_package`, `06_java_package` and `08_swift_package` list `FrameSession`, `ReplayWindow`, `MacKey`, the error kinds and the figures measured on HEAD in the same loop; `tests.md` / `tests-by-loop.md` list the new tests; `module-layout.md` lists the new files.
- The contract Change Log of `pack-session.md` records the three consumers with the vectors they pass (no version bump: no byte changes).

## Scope

### Included
- `README.md`, `_docs/02_document/components/{01_csharp_package,06_java_package,08_swift_package}/`, `_docs/02_document/module-layout.md`, the Change Log of `_docs/02_document/contracts/library/pack-session.md`.

### Excluded
- Any code; the other packages; ADR changes.

## Acceptance Criteria

**AC-1: Examples run**
Given each README example
When its package's example test runs
Then it passes, and the README text equals the test's code (checked by a diff of the fenced block against the file region)

**AC-2: Components and layout complete**
Given the three component descriptions and `module-layout.md`
When each new public type and each new source file of the three tasks is looked up
Then 0 are missing

**AC-3: Contract note**
Given the contract Change Log
When read
Then it names C#, Java and Swift as passing `fixtures/frame/vectors.txt` and the contract version is unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | diff of README fences against the example test regions | 0 differences |
| AC-2 | grep of type and file names in the docs | 0 missing |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the three package suites green | run the example tests | pass | — |

## Constraints

- Figures in the docs (sizes, counts) are read from a run on HEAD in the same loop.
- The parent edits shared docs; workers do not.

## Risks & Mitigation

**Risk 1: Example drifts from the README**
- *Risk*: the README code and the tested code differ.
- *Mitigation*: AC-1 diff check.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
