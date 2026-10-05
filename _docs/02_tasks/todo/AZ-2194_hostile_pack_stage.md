# Hostile vectors gain a pack stage

**Task**: AZ-2194_hostile_pack_stage
**Name**: `pack` stage in the shared vector file
**Description**: `fixtures/hostile/cases.txt` gains a `pack` case kind whose expected outcome is the packet bytes or a pack refusal, with five first cases, so the behaviors that refuse input at pack time are checked by every package that can express them against one shared file.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors (the file, its format check and the six package loaders), AZ-2179_rounds_ring (the aligned round shape and its bytes)
**Component**: shared harness (`fixtures/hostile/`, the scaffold job, the six packages' vector tests)
**Tracker**: AZ-2194
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (harness gap), owner scope A on 2026-10-05: not fixed in loop 13, filed as a follow-up.

- `cases.txt` has 17 cases: 10 `unpack` and 7 `construct`. No `pack` stage exists, and `check-cases.sh` accepts only those two stages.
- The loop 13 behaviors that refuse input at pack time are pinned only by per-package tests: the TypeScript range check (AZ-2084), C# loud missing value and `times` length (AZ-2088), aligned round rows. Loop 13 added no vector, so nothing keeps the six packages answering alike.
- Some packages cannot express a case: C++, Rust typed rows and C# typed rows have static types, so an out-of-range integer or a missing value cannot be written in them. A pack stage must say which packages run each case.
- The Java and Rust vector tests stop with "unknown stage" on a stage they do not know, and the C++ and other loaders read the same four columns. A new stage must not break them.

## Outcome

- A `pack` case states a scheme and row (in the README section, not in the file) and an expected outcome: the packet `bytes`, or `pack_error` (pack throws or returns an error, and returns no bytes).
- Five cases cover an out-of-range integer, a missing required value, a `times` list that is too long, one that is too short, and an aligned round row.
- Each case names the packages that run it and the packages that do not, with the reason. The format check and its self-test cover the new kind, and every package's vector test handles it.

## Scope

### Included
- The `pack` stage and the `pack_error` term in the file format, `check-cases.sh`, its self-test and the README.
- The five cases below, run by the packages that can express them.
- In each package's vector test, a `pack` case runs or is reported as skipped with the named reason.

### Excluded
- Changes to any package's pack behavior (AZ-2185, AZ-2186, AZ-2187, AZ-2190 to AZ-2192 own those).
- Asserting the error type or message text, or that the member is named: each package ticket does that.
- Session pack, a second aligned shape (`roundwhen` stays in the ring), and any `unpack` or `construct` case.

## Acceptance Criteria

**AC-1: The format accepts a pack line**
Given lines `id pack bytes <hex>` (lowercase, even length, starting `01`) and `id pack pack_error -`
When `check-cases.sh` runs
Then both are accepted and counted; the committed file reports `hostile cases ok: 22`.

**AC-2: The format rejects a malformed pack line**
Given a pack line with `bytes` and hex `-`, with `pack_error` and a hex, with odd or non-`01` hex, with an `unpack` term such as `short_packet`, or an `unpack` or `construct` line using `bytes` or `pack_error`
When the check runs
Then it fails and names the line.

**AC-3: Each pack case is documented**
Given a `pack` case
When the check runs
Then it requires a README section for the id that gives the scheme, the row, a `Run by` list and a `Not run by` list with a reason per package; together the two lists name each of the six packages exactly once.

**AC-4: Out-of-range integer**
Given `u8 a` and the row `a = 300`
When each package that can express it packs the row
Then `pack_error`. Run by TypeScript, Python, Java, C# (dictionary rows); not C++ or C# typed rows (static types). Rust's map form runs it if 300 can be supplied for a `u8`, otherwise it is named with the reason.

**AC-5: Missing required value**
Given `u8 a; u8 b` and the row `{a: 1}`
When it is packed
Then `pack_error`. Run by TypeScript, Python, Java, C# (dictionary rows) and Rust (map form); not C++ (typed rows always hold a value).

**AC-6: `times` list of the wrong length**
Given `u8 a; times(1, 0, u8 x)` with `a = 2`
When it is packed with `x = [1, 2, 3]` (`pack_times_list_too_long`) and with `x = [1]` (`pack_times_list_too_short`)
Then both give `pack_error`. Run by C# and Rust (map form) for both; TypeScript, Python and Java for the short list. For the long list they are listed under `Not run by` (accepted today: AZ-2185, AZ-2186, AZ-2187) and move to `Run by` in those tickets. Not C++ (fixed-size arrays).

**AC-7: Aligned round row**
Given `repeat(flags(bool on, u8 n))` with `on = [true, false, true]` and `n = [1, 2, 3]`
When it is packed
Then the bytes are `01030102020303` (`bytes`). Run by C#, TypeScript, Java and Rust (map form); Python is named under `Not run by` (AZ-2134); C++ only if AZ-2179 finds its array rows can express it.

**AC-8: Every package's vector test handles the stage**
Given the extended file
When each of the six packages' vector tests runs
Then none fails on the new stage; each case asserts its outcome where listed in `Run by` and is reported skipped with its reason where listed in `Not run by`; the existing 17 cases give the same results as before.

**AC-9: The scaffold job validates the new kind**
Given the `hostile case file` step of the scaffold job
When it runs
Then it runs the check and the self-test with the new count and the corruptions of AC-2 and AC-3, and fails if any of them passes.

## Non-Functional Requirements

**Compatibility**
- The file keeps four columns (`id stage expected hex`), UTF-8, LF; the existing 17 lines are not edited.

**Reliability**
- A pack case outcome does not depend on time or order. A listed package that cannot run its case fails; it is never skipped silently.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | committed file | `hostile cases ok: 22` |
| AC-2 | six corrupted copies (one per bad shape) | each rejected, line named |
| AC-3 | a pack case without a section, with a package missing from both lists, with a package named twice | each rejected |
| AC-4 to AC-7 | each package's vector test for its `Run by` cases | outcome matches; skipped cases name their reason |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-8 | the six package suites | run the vector tests | green; skipped cases listed with reasons | Reliability |
| AC-9 | CI scaffold job | push | the check and self-test pass | Compatibility |

## Constraints

- ADR-001: the file holds bytes and outcomes only; each package writes the scheme and the row by hand from the README.
- Bytes come from the wire rules and AZ-2179 (`01030102020303`); each package re-derives them from a real run before it pins them.
- All six loaders and the file change together, so no package sees the new stage before it handles it.

## Risks & Mitigation

**Risk 1: A loader fails on the new stage**
- *Risk*: Java and Rust stop on an unknown stage.
- *Mitigation*: one change touches the file and the six loaders (AC-8).

**Risk 2: `Not run by` lists go stale**
- *Risk*: TypeScript, Python and Java stay listed after AZ-2185 to AZ-2187 land.
- *Mitigation*: those tickets move their package to `Run by`; the check keeps the lists a partition of the six.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One `pack_error` kind for every refusal (out-of-range, missing, length); per-cause kinds could be added later | owner | open | Low |
| Pack errors throw in most packages, unlike `unpack` (the README says `unpack` never throws); the README intro needs the exception stated | spec scope | resolved | Low |
| Rust map-form and C++ coverage of each case is decided by the worker against the real public API | worker, named in the case section | open | Low |
