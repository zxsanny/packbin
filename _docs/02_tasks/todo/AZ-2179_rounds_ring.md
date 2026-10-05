# Cross-language rounds ring

**Task**: AZ-2179_rounds_ring
**Name**: Rounds ring in `language-pair.sh`
**Description**: Two cross-language rings (`roundflags`, `roundwhen`) prove that aligned `repeat` rows give the same bytes and the same aligned rows in every package whose rows can express them.
**Complexity**: 5 points
**Dependencies**: AZ-2087_csharp_forward_refs, AZ-2091_typescript_nested_flags_names, AZ-2086_rust_typed_times_vec (map form), AZ-2175_csharp_when_on_written_values
**Component**: shared harness (`.github/workflows/language-pair.sh` and the per-language drivers under `.github/workflows/drivers/`)
**Tracker**: AZ-2179
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X1), owner scope A on 2026-10-05. Aligned rounds (`repeat` / `times` with `flags` or `when` in a round: one list entry per round, a null for a skipped round) are checked only by per-package tests. `language-pair.sh` has no ring that uses `repeat` or `times`, so project AC-3 (bytes identical across languages) is not exercised for them, although AZ-2134 AC-1 names the cross-language bytes.

## Outcome

- A producer in one language and a consumer in the next agree on bytes and on the aligned row for two round shapes.
- Languages that cannot express a shape are named, with the reason, in a comment on the ring.

## Scope

### Included
- A `roundflags` ring and a `roundwhen` ring in `language-pair.sh`.
- Pack and unpack commands in the drivers of C#, TypeScript, Java and Rust (map form); C++ if its array rows can express the shapes.
- The expected hex constants next to the existing ones.

### Excluded
- Python (joins with AZ-2134).
- Wiring the rings into CI (a separate follow-up; the rings stay a manual gate for now).
- New wire features.

## Acceptance Criteria

**AC-1: `roundflags`**
Given `repeat(flags(bool on, u8 n))` with `on = [true, false, true]` and `n = [1, 2, 3]`
When any ring member packs it
Then the bytes are `01030102020303`, and every other member reads `on = [true, null, true]` and `n = [1, 2, 3]` (null is each language's absent value).

**AC-2: `roundwhen`**
Given `repeat(u8 k, when(k == 1, u8 v))` with `k = [1, 2]` and `v = [9]`
When any ring member packs it
Then the bytes are `01010902`, and every other member reads `k = [1, 2]` and `v = [9, null]`, and repacking that row gives `01010902`.

**AC-3: Omissions are explicit**
Given a language whose rows cannot express a shape
When the ring runs
Then the ring comment names that language and the reason, and the ring still passes for the others.

**AC-4: Existing rings stay green**
Given the existing rings (`user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `position`)
When `language-pair.sh` runs
Then they all pass with unchanged hex constants.

## Non-Functional Requirements

**Compatibility**
- No production change in any package; drivers only.

**Reliability**
- The script stays deterministic and finishes in about a minute on the host toolchains.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | each driver's new pack and unpack commands | print the expected hex / row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | host toolchains, six drivers | `roundflags` ring | 0 mismatched bytes, aligned rows agree | Compatibility |
| AC-2 | same | `roundwhen` ring | 0 mismatched bytes, aligned rows agree | Compatibility |
| AC-4 | same | all rings | all pass | Compatibility |

## Constraints

- ADR-001: no shared walker; each driver uses its package's public API only.
- Driver files stay under 500 lines; ownership is per package (`drivers/csharp/**`, `drivers/handoff.ts`, `drivers/Handoff.java`, `drivers/handoff-rust/**`, `drivers/handoff.cpp`); `language-pair.sh` is written once by the coordinator.

## Risks & Mitigation

**Risk 1: A package cannot express a shape through its public API**
- *Risk*: C++ rows are fixed arrays; Rust typed rows have no typed `repeat`.
- *Mitigation*: AC-3 allows a named omission; Rust uses the map form, which carries per-name lists.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ring script is not run by CI (project AC-3 is gated manually) | follow-up (assessment X2; analysts recommend a CI job) | open | Medium |
