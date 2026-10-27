---
loop: 76
branch: dev
---

# Hostile probes: the C# probe project runs, and the NFC/NFD check uses ascending keys

**Task**: AZ-3329_probe_fixes
**Name**: C# probe project without the second entry point; NFC/NFD edges check in ascending key order (C#, Java)
**Description**: The C# hostile probe builds and runs, and the C# and Java `edges` probes pass their NFC/NFD check.
**Complexity**: 2 points
**Dependencies**: None
**Component**: hostile fuzz probes (`fixtures/hostile/fuzz/`)
**Tracker**: AZ-3329
**Epic**: AZ-2645

Items 2 and 6 of `_docs/02_task_plans/hygiene-after-frame-ports/problem.md`. Owner, 2026-10-27: "Accept all recommended".

## Problem

`PackbinProbe.csproj` also compiles `ns20/Program.cs` through the SDK default glob: the build warns `CS7022` and `PackbinProbe <repo> edges` dies with `System.FormatException` (exit 134), so nobody can run the probe as the csproj header says. With that fixed, the C# `edges` probe prints 63 PASS and 1 FAIL and the Java one 64 PASS and 1 FAIL, both "dict: NFC and NFD forms of é are two keys". The probes pass the keys NFC (`c3 a9`) then NFD (`65 cc 81`); dictionary keys must ascend strictly by UTF-8 bytes (loop 42), so that packet is refused. The packages are right, the probe packet is wrong (proved on scratch copies: keys swapped gives C# 64 PASS and Java 65 PASS, exit 0).

## Outcome

- The C# probe builds from a copy outside the checkout with 0 `CS7022` warnings and its `edges` command runs.
- The C# `edges` probe ends 64 PASS, 0 FAIL, exit 0; the Java one 65 PASS, 0 FAIL, exit 0.

## Scope

### Included
- `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` (leave `ns20/**` out of the compile), `fixtures/hostile/fuzz/csharp/EdgesText.cs` (the NFC/NFD check, NFD key first), `fixtures/hostile/fuzz/java/packbin/ProbeEdgesText.java` (the same).

### Excluded
- Any file under `csharp/*.cs` or `java/src/main` (the packages are right); the Swift, Python and TypeScript probes (they report the NFC/NFD case as information, by design: Swift F47); a descending-order probe (the dictionary-order tests pin it: scenario S10).

## Acceptance Criteria

**AC-1: Builds without the second entry point**
Given the build command in the csproj header, run on a copy of `fixtures/hostile/fuzz/csharp` outside the checkout
When it runs
Then it reports 0 errors and 0 warnings `CS7022` (1 today)

**AC-2: Runs**
Given the built probe
When `PackbinProbe <repo> edges` runs
Then it prints one PASS or FAIL line per case and exits 0 or 1, with no exception (exit 134 today)

**AC-3: The netstandard2.0 probe is unharmed**
Given `ns20/Ns20Utf8Probe.csproj` copied out of the checkout
When it is built with the command in its header
Then it reports 0 errors

**AC-4: C# edges**
Given the C# probe after AC-1
When `edges` runs
Then 64 PASS, 0 FAIL, exit 0 (63 PASS and 1 FAIL today, after AC-1)

**AC-5: Java edges**
Given the Java probe compiled with `javac --release 17 -encoding UTF-8` as in `AuditProbe.java`
When `edges` runs
Then 65 PASS, 0 FAIL, exit 0 (64 PASS and 1 FAIL today)

**AC-6: Packages untouched**
Given the diff of this task
When it is read
Then no file under `csharp/*.cs` or `java/src/main` is in it

Project ACs exercised: the loop 42 ascending dictionary-key rule (unchanged).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | build log | `0 Error(s)`, no `CS7022` |
| AC-4 | `edges` output | 64 `PASS`, 0 `FAIL`, exit 0 |
| AC-5 | `edges` output | 65 `PASS`, 0 `FAIL`, exit 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-3 | copies under the scratchpad, `MSBUILDDISABLENODEREUSE=1` | build and run both C# projects | as the ACs | — |

## Constraints

- Copy the probe folder out of the checkout before building (the csproj header says so: `obj/` and `bin/` must not land in the repository). macOS has no `timeout`: use `perl -e 'alarm N; exec @ARGV' --`; every command takes stdin from `/dev/null`.
- A worker runs no `git add`, `rm`, `mv`, `restore --staged`, `stash`, `checkout`, `reset` or `clean`, and no formatter on files it does not own.

## Risks & Mitigation

**Risk 1: the swapped order hides a real refusal**
- *Risk*: the probe now only shows the accepted order.
- *Mitigation*: the package dictionary-order tests already pin the descending refusal (S10); this task does not weaken them.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The Java and C# probes disagreed with the loop 42 rule since loop 42 and nobody ran them (C# could not run) | note in the loop record | resolved | Low |
