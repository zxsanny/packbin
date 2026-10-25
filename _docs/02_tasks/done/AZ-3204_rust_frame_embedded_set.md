---
loop: 69
branch: dev
---

# Rust frame mode: embedded `frame` set, feature switch, docs

**Task**: AZ-3204_rust_frame_embedded_set
**Name**: Embedded `frame` feature set on the Cortex-M4F, feature switch checks, docs (PB-04, part 2)
**Description**: The embedded stage builds and runs a `frame` feature set with recorded flash and stack figures and limits, proves the existing sets and the stream code are untouched, and the Rust docs describe frame mode.
**Complexity**: 3 points
**Dependencies**: AZ-3203_rust_frame_mode_core
**Component**: Rust embedded stage (`rust/embedded`), Rust README and component description
**Tracker**: AZ-3204
**Epic**: AZ-3199

## Problem

meshbell's relays run on a Cortex-M4F part without heap or panic path, so the frame code must be proven on the device image the way the text, ecc and session sets are, with limits so a later edit cannot grow it silently. Full spec: `_docs/02_task_plans/rust-m33f-and-frame-mode/input/PB-04_rust_frame_mode.md` (AC-7, AC-8).

## Outcome

- The embedded stage lists a `frame` feature set whose probe seals and opens E1 with a replay window and computes and verifies E4; `limits.txt` gets its flash and stack at the measured figure plus 5% (never above 20,480 B and 2,048 B).
- The four existing sets (base 16384 / 512, text 27964 / 2898, ecc 18879 / 798, session 19325 / 1924 are the limits) report the same figures with `frame` off; with `frame` on and `session` off no stream-session symbol is linked.
- Docs: Rust README section with the seal, open-with-window and MAC-only example; the Rust component description records the frame feature, its sizes (`ReplayWindow` 16 B, `MacKey` at most 72 B, frame `Session` at most 640 B) and the measured embedded figures.

## Scope

### Included
- `rust/embedded/feature-sets.txt`, `limits.txt`, the probe crate, `checks.sh` use, `README.md`; the Rust package README and `_docs/02_document/components/04_rust_package/description.md`; CI job wiring only if the stage needs it.

### Excluded
- The frame code itself (AZ-3203); other packages; a real nRF52840; the Cortex-M33F row of the Rust stage (loop 70).

## Acceptance Criteria

**AC-1: Device** (S11)
Given the embedded stage (Cortex-M4F, `mps2-an386`) with the `frame` set, whose probe seals and opens E1 with a window and computes and verifies E4
When `checks.sh` and the stage run
Then no heap or panic symbol is linked, the E1 round trip and the E4 verify match on the device, stack is at most 2,048 B and flash at most 20,480 B, and both figures with their limits (measured plus 5%) are in `limits.txt`

**AC-2: The feature switch** (S11)
Given `frame` off
When the existing four feature sets are built
Then their flash and stack figures differ by 0 B from before this loop; and with `frame` on and `session` off, 0 stream-session symbols are linked

**AC-3: Docs record it**
Given the Rust README and the component description
When they are read
Then the frame example runs as written, and the three sizes and the embedded figures are stated

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `checks.test.sh` and the stage's mutants (seeded panic and heap) with the `frame` set | the checks still catch both seeds |
| AC-2 | `checks.test.sh` on a `frame`-off and a `frame`-on `session`-off image | 0 B difference; 0 stream symbols |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | HEAD with the change | `rust/embedded/run.sh host`, then the `embedded-rust` CI job | all sets within their limits; `frame` row reported | stack 2,048 B, flash 20,480 B |
| AC-3 | HEAD | the README example compiled as a doc test or a test file | passes | — |

## Constraints

- Fit decision 3: one `frame` set; limits at the measured figure plus 5%; the other four sets keep their figures; `std` includes `frame` as it includes `session`.
- A raise of any limit needs a line in `limits.txt` saying what the bytes bought.
- The probe uses the same startup code, linker script, stack meter and QEMU runner as the other sets (one method for all figures).

## Risks & Mitigation

**Risk 1: Stack of the MAC over parts on the device**
- *Mitigation*: no joined copy of the message; AC-1 bounds the stack at 2,048 B.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The embedded stage needs Docker and QEMU on this Mac; the run may be long | long-runs rule: stage-by-stage with a 30 s watcher | accepted-risk | Low |
