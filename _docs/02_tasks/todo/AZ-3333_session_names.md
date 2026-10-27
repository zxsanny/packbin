---
loop: 76
branch: dev
---

# The "Session" tests and fuzz probes get names that match what they test

**Task**: AZ-3333_session_names
**Name**: Rename `TopRangeAndSessionTests`, `EccSessionTextTests` and `fuzz_ecc_session.*`
**Description**: After the stream session was removed (ADR-009), two C# test classes and two fuzz probe files still carry its name.
**Complexity**: 2 points
**Dependencies**: None
**Component**: 01_csharp_package (tests) and hostile fuzz probes (`fixtures/hostile/fuzz/`)
**Tracker**: AZ-3333
**Epic**: AZ-2645

Item 7 of `_docs/02_task_plans/hygiene-after-frame-ports/problem.md`. Names only.

## Problem

`csharp/tests/TopRangeAndSessionTests.cs` (126 lines) now tests top-range values and typed rows, `csharp/tests/EccSessionTextTests.cs` (112 lines) tests error correction with text, and `fixtures/hostile/fuzz/python/fuzz_ecc_session.py` and `fixtures/hostile/fuzz/typescript/fuzz_ecc_session.ts` fuzz the repair and the clear protected unpack. None touches a session. `git grep -n "TopRangeAndSessionTests\|EccSessionTextTests\|fuzz_ecc_session"` outside loop history finds 10 lines in 10 files: the four files, `fixtures/hostile/fuzz/README.md`, `fuzz_common.py`, `fuzz_common.ts`, and the C# `description.md`, `tests-by-loop.md` and `module-layout.md`.

## Outcome

- The names say what the tests do (the probe files follow the `fuzz-ecc` command and the `FuzzEcc.cs` / `ProbeFuzzEcc.java` names of the other languages); the readers are updated; behavior is equal.

## Scope

### Included
- The two C# test files (file and class names; `mv`, not `git mv`), the two fuzz probe files, and the six reader files above. The history notes in `_docs/` that say "was named" keep the old name once, as history.

### Excluded
- `_docs/loops/`, `_docs/02_tasks/done/`, `_docs/03_implementation/` (history); any test body; the Go, Swift, Rust, Java and C++ files (they carry no such name); the test count.

## Acceptance Criteria

**AC-1: No stale name**
Given the tracked files outside `_docs/loops/`, `_docs/02_tasks/done/`, `_docs/03_implementation/` and `_docs/02_task_plans/hygiene-after-frame-ports/`
When `git grep -n "TopRangeAndSessionTests\|EccSessionTextTests\|fuzz_ecc_session"` runs
Then it prints 0 lines (10 lines in 10 files today), except one history sentence per renamed item that names the old name together with the new one, if the worker keeps one

**AC-2: Same tests, same results**
Given the C# suite (`env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`) and the two renamed fuzz probes
When they run before and after the rename
Then the C# test count and result are equal, and each fuzz probe exits with the same code and prints the same set of PASS lines

**AC-3: No collision**
Given the new file and class names
When they are looked up in the repository
Then none exists already (a new C# class name is unique in the test project)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the `git grep` | 0 lines |
| AC-2 | C# suite before and after | equal count, PASS |
| AC-2 | `fuzz_ecc` (Python) and (TypeScript) before and after | equal exit code and PASS lines |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | `python3.14 -I -B fuzz_ecc.py <repo> 1 2`, `node fuzz_ecc.ts <repo> 1 2` | the probes | as before the rename | — |

## Constraints

- Before the rename, `git grep` every reader and run each (AGENT_GOTCHAS: loops 34 and 39 missed readers). `dotnet test` always with `MSBUILDDISABLENODEREUSE=1` (it hangs forever without it on this Mac).
- A worker runs no `git add`, `rm`, `mv`, `restore --staged`, `stash`, `checkout`, `reset` or `clean`: rename with plain `mv`; the parent stages.

## Risks & Mitigation

**Risk 1: a script or CI file lists a test by class or file name**
- *Risk*: a rename breaks a selection.
- *Mitigation*: the `git grep` of AC-1 covers every tracked file, `.github/` included; no script names them today.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A doc outside the readers lists the old class by another spelling | `git grep -i "session"` in the touched docs | open | Low |
