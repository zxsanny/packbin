---
loop: 125
branch: dev
---

# Probe how deep a scheme may be in all nine packages

**Task**: AZ-4291_scheme_depth_probe
**Name**: Probe how deep a scheme may be in all nine packages (when / group chains)
**Description**: Committed probes that show, per package, what happens when a scheme is built, packed and unpacked at a depth of 1,000, 5,000 and 50,000 nested `when`s or groups; one findings table.
**Complexity**: 3 points
**Dependencies**: none
**Component**: `scripts/probes/scheme-depth/` (new), `_docs/06_metrics/` (findings); no package source
**Tracker**: AZ-4291
**Epic**: AZ-4133

Queue item `dart-deep-when-chain-stack-overflow` (found loop 113), decision D9 applied at A (probe first). Problem: `_docs/02_task_plans/scheme-depth-probe/problem.md`.

## Problem

A Dart scheme of 5,000 nested `when`s dies with a raw `Stack Overflow` at build, not a `schemeError`. The other eight packages were never measured for scheme depth. No package has a depth limit (`git grep` for depth rules finds none).

## Shapes

One process per shape and depth; field ids as each package numbers them. `D` = 1000, 5000, 50000.

| shape | scheme | values |
|-------|--------|--------|
| `when-D` | `u8 a` (id 0); then D nested `when(a == 1, ...)`, each holding the next; the innermost holds `u8 b` (id 1). Type number 1 | `{a: 1, b: 7}`: packs `01 01 07` |
| `group-D` | D nested groups, the innermost holding `u8 b`. Type number 1. The form is the package's own: a group without an anchor (nested row) in C#, Java, Go, Swift and Dart; in TypeScript, Python, Rust and C++ the nesting the package has (an anchored group that shares the row, or a group inside a group); the probe says which at the top of its source and in the README | the nested map / row D deep where the package nests values, else flat; `b` = 7; packs `01 07` where no flag byte is needed |

Only a package whose API has no such form says `n/a: <why>`.

## Acceptance Criteria

**AC-1: One probe per package.** Given `scripts/probes/scheme-depth/run.sh` with no argument, when it runs on this Mac, then each of typescript, java, go, swift, rust, python, cpp, csharp and dart prints one tab-separated line per shape and depth (`package`, `shape`, `build`, `pack`, `unpack`; the format of `scripts/probes/element-row/README.md`), and the run exits 0.

**AC-2: A crash is a line.** Given a case that kills its process (stack overflow, abort, signal), when the run reaches it, then its line says `crashed: <exit status or signal>`, the other cases still run, and a raw language stack error that the program can catch is printed `threw: <type>`, distinct from the package's own `refused: <message>`.

**AC-3: Findings.** Given the probe output, when `_docs/06_metrics/scheme-depth-probe_2026-11-14.md` is written, then it has one row per package, shape and depth with the outcome class (built and round-trips / refused with the package's error / raw stack error / crash / n/a), the largest depth that works per package and shape (between the three depths, not bisected), and the class stated once with the packages that need a task and a recommended decision for D9.

**AC-4: Repeatable and clean.** Given two runs on the same checkout, then the outputs match line for line (the text of a crash status may be normalised) and `git status` shows no file written by the probe.

**AC-5: No package change.** Given the loop's diff, then no file under `typescript/`, `java/`, `go/`, `swift/`, `rust/`, `python/`, `cpp/`, `csharp/`, `dart/` changed.

## Non-Functional Requirements

Whole run about 5 minutes at most; each case has a time limit (60 s) so a hang is a line (`crashed: timeout`). `bash -n` and `shellcheck` clean.

## Constraints

Probe only; a fix follows the owner's decision for the class. Builds go to a temporary directory outside the repository. Go runs in `golang:1.27` when `go` is not on `PATH`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A probe that overflows the stack must not take the run down | each case is its own process with a time limit | resolved | Low |
