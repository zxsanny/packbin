---
loop: 92
branch: dev
---

# AVR runtime check of chacha20_xor

**Task**: AZ-3452_avr_chacha20_runtime_check
**Name**: AVR runtime check of chacha20_xor
**Description**: The arm stage runs one image on an AVR emulator that checks `chacha20_xor` on a 16-bit `size_t`, and fails the `cpp-avr-uno` row when any check fails.
**Complexity**: 5 points
**Dependencies**: None
**Component**: cpp embedded stage (`cpp/embedded`: image recipe, `target_avr_uno` in `arm.sh`, new AVR harness files; `README.md`)
**Tracker**: AZ-3452
**Epic**: none

## Problem

The C++ core builds for the ATmega328P (16-bit `int` and `size_t`) and CI links the Uno example, but no AVR image is ever run. `chacha20_xor` counts the remaining bytes down because an offset stepping by 64 "would wrap a 16-bit `size_t`"; that claim, the block-count arithmetic and the 32-bit counter limit have run on 32-bit and 64-bit hosts only. The owner chose to run them on a 16-bit target in an emulator (loop 92, from the loop 91 handoff).

## Outcome

- One AVR image runs on an emulator in CI and checks `chacha20_xor` against the RFC 8439 vector, a byte-for-byte stream rebuilt from `chacha20_block`, and the 32-bit counter edge.
- A wrong byte, a hang, a silent run or a missing emulator turns the `cpp-avr-uno` row red.
- The two sentences that say no AVR image is run are corrected.

## Scope

### Included
- The emulator in the embedded image used by the arm stage.
- A small AVR harness image (C and C++ files under `cpp/embedded/avr/`) that reports over the UART, linked with the core's crypto file built with the Uno flags.
- A run-and-check step inside `target_avr_uno`, with a host time limit and a check that the report is complete.
- `README.md` and the `arm.sh` comment: say that one image runs and what it checks.

### Excluded
- Any change under `cpp/src` or `cpp/include` (a defect found by the run stops the loop and is reported, no expectation is relaxed).
- Other crypto functions on AVR, cycle counts, real hardware.
- A buffer near 64 KiB (the part has 2 KB of RAM; see Flagged concerns).

## Acceptance Criteria

**AC-1: The image runs on an emulated ATmega328P**
Given the arm stage with the AVR emulator in the image
When `target_avr_uno` runs the harness image on an ATmega328P at 16 MHz
Then the image ends on its own and reports `sizeof(size_t)` = 2 and `sizeof(int)` = 2 read from the emulated CPU (2 of 2 sizes read, 0 assumed)

**AC-2: The RFC 8439 vector**
Given key `00..1f`, nonce `000000000000004a00000000`, counter 1 and the 114-byte plaintext of RFC 8439 §2.4.2
When `chacha20_xor` runs on the emulated part
Then 114 of 114 ciphertext bytes equal the RFC ciphertext

**AC-3: Lengths around the block size**
Given 9 lengths (0, 1, 63, 64, 65, 114, 127, 128, 129)
When `chacha20_xor` runs on each
Then each result equals the stream built block by block from `chacha20_block` (9 of 9) and a second `chacha20_xor` restores the plaintext (9 of 9)

**AC-4: The 32-bit counter edge**
Given the five cases of the host test `block_counter_edge`
When they run on the emulated part
Then 5 of 5 behave as there: counter `0xffffffff` with 64 bytes returns true and equals that block; `0xfffffffe` with 128 bytes returns true and equals the two blocks; `0xffffffff` with 65 bytes and `0xfffffffe` with 129 bytes return false with 0 bytes changed; `0xffffffff` with 0 bytes returns true

**AC-5: The gate fails when it should**
Given the harness image, the emulator and the stage
When the image prints a failing check, a pass count other than the expected total, no output, or does not end within 30 s of host time, or the emulator is missing from the image
Then the `cpp-avr-uno` row fails (the stage exits 1) and names the cause; with one injected defect (one changed expected byte, or one changed line in `chacha20_xor`) run through the real path and reverted at once, the row fails and names the set

**AC-6: Warnings, budgets, scope of change**
Given the existing core flags `-Wall -Wextra -Werror` and the Uno budgets
When the harness builds and links
Then 0 warnings, flash ≤ 32,256 B, static RAM ≤ 2,048 B, the existing Uno example figures unchanged, `cpp/embedded/lib.test.sh` and `cpp/embedded/run-parts.test.sh` pass unchanged, and no file under `cpp/src` or `cpp/include` changes

**AC-7: The stale statements**
Given `README.md` and the comment above `avr_arch` in `cpp/embedded/arm.sh`
When read after the change
Then 0 of the 2 sentences "no AVR image is run" and "Build only: no AVR emulator runs the image" are left; each says that one image runs on the emulator and what it checks

## Non-Functional Requirements

**Performance**
- The run itself ends in under 30 s of host time (the probe ended in under 1 s); the figure added to the `cpp-avr-uno` row is measured in the task and written in the report.

**Compatibility**
- The image recipe is shared with the Rust embedded stage; its figures and rows stay as they are.

**Reliability**
- The check is deterministic: no clock, no random input, same output on every run.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | the report check is one `diff` against `chacha20_expected.txt`, so no separate parser test: the four real-path failure runs below cover it (a separate test script would need new CI wiring in four files) | see Blackbox Tests |
| AC-6 | `cpp/embedded/lib.test.sh` and `run-parts.test.sh` fakes | pass unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-4 | the `packbin-embedded` image rebuilt with the emulator | `cpp/embedded/run.sh arm` (the `cpp-avr-uno` row) | the row passes; the log holds the sizes, 114 of 114, 9 of 9 twice, 5 of 5 | Performance, Reliability |
| AC-5 | one expected byte changed in the harness | the same run | the row fails and names the check; revert, row passes | Reliability |
| AC-5 | emulator removed from `PATH` | the same run | the row fails naming the missing tool | Reliability |
| AC-6 | the same run | warnings, flash and RAM lines of the row | 0 warnings, within budgets | — |
| AC-7 | `git grep` of the two sentences | the docs | 0 matches | — |

## Constraints

- Output goes over the UART: simavr 1.6 prints nothing for its console register, and its header does not compile as C++.
- The gate strips the colour codes and handles the non-printable bytes simavr shows as `.`.
- No new report row: the check extends `target_avr_uno`, so the pinned row counts of the test scripts stay as they are.

## Risks & Mitigation

**Risk 1: The emulator package disappears or changes**
- *Risk*: the package comes from Ubuntu universe at image build.
- *Mitigation*: the stage fails with the missing tool named; the image recipe is the only place it is named.

**Risk 2: The run shows a defect in `chacha20_xor`**
- *Risk*: the first run on 16 bits may fail.
- *Mitigation*: the loop stops and reports; no expectation is relaxed and no stub is added.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The wrap the comment names needs a buffer near 64 KiB; an ATmega328P has 2 KB of RAM and no AVR part has a 64 KiB data space in RAM, so the run cannot reach it. It checks 16-bit `int` and `size_t` arithmetic in the length, block-count and counter-limit paths (lengths 0 to 129, counters at the 32-bit edge), not the wrap region itself | owner informed in the loop 92 summary; limit found after it | open | Medium |
| The emulator joins the shared `packbin-embedded` image (also run by the Rust embedded stage) | none stated | open | Low |
| The emulator output carries colour codes and shows non-printable bytes as `.` | none stated | open | Low |
