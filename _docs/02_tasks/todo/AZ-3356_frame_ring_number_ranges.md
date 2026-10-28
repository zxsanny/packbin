---
loop: 79
branch: dev
---

# Frame ring: one number range rule for every driver and row

**Task**: AZ-3356_frame_ring_number_ranges
**Name**: Frame ring number ranges
**Description**: Every number on a frame driver line has a fixed range that all 8 drivers and the ring loader enforce; the checker no longer hides mismatches past the fifth.
**Complexity**: 3 points
**Dependencies**: AZ-3354, AZ-3355 (shipped in loop 78)
**Component**: cross-language frame ring (`.github/workflows/ring-frame.sh`, drivers, `scripts/frame/ring_frame.py`)
**Tracker**: AZ-3356
**Epic**: none

## Problem

The 8 frame drivers of the ring read decimal numbers and hand them to their package. On HEAD `cb6759b` (probe ring, loop 79): C#, C++ and Go cast a direction to a byte, so 257 becomes `Up` and is sealed and opened; C++ also wraps a tag length of 260 to 4 and a kind of 256 to 0; Go wraps an epoch of 4,294,967,297 to 1 in seal and MAC. The reference refuses all of these with `BadValue`, so a ring row holding such a value would blame a correct package. Python takes a sign (`-255`), C# and Java take a sign or spaces. A huge `out_len` is allocated as given: 2,147,483,647 runs C# and Java out of memory, 1,099,511,627,776 gets the Python and Swift drivers killed by the OS. The checker prints at most 5 mismatch lines for a pair or a reader and is silent about the rest (C++ had 7 in the probe and showed 5).

## Outcome

- One rule, the same in all 8 drivers and the loader: a number is decimal digits only and lies in its field's range, or the line is malformed.
- No driver narrows a number or allocates more than 65,535 bytes for a caller's buffer.
- Every mismatch is visible as a line or counted in a `... and N more` line.

## Scope

### Included

- The ranges: `dir`, `tag_len`, `kind`, `n` 0 to 255; `epoch` 0 to 4,294,967,295; `out_len`, `clear_len` 0 to 65,535; digits only (no sign, space, `+`, `_`); leading zeros allowed. Every number field of `seal`, `open`, `mac`, `verify` lines in the 8 drivers under `.github/workflows/drivers/` (`handoff_frame.py`, `handoff-frame.ts`, `HandoffFrame.java`, `csharp/HandoffFrame.cs`, `handoff-go/frame.go`, `handoff-rust/src/frame.rs`, `handoff-swift/Sources/handoff-swift/Frame.swift`, the frame section of `handoff.cpp`).
- A number outside its range ends the driver as a malformed line does since AZ-3355: non-zero exit, no result line for it, a message naming the line.
- `scripts/frame/ring_frame.py` refuses a `ring-cases.txt` row with a number outside its range (exit 1, row named).
- `fixtures/frame/ring-cases.txt`: 6 rows at the top of the ranges (direction 255, tag length 255, kind 255 and epoch 4,294,967,295 as `refuse-seal` `BadValue`; `n` 255 as `refuse-mac` `BadValue`; a `seal` row with `out_len` 65,535).
- `fixtures/frame/README.md`: the ranges and the digits-only rule.
- `ring_frame.py check`: after 5 mismatch lines of a pair or a reader, one line `... and N more`.
- `.github/workflows/ring-frame-drivers.test.sh`: the out-of-range and top-of-range cases on the real drivers; `.github/workflows/ring-frame.test.sh`: the loader and display cases.

### Excluded

- Multi-part MAC rows, key and `msg_id` length refusals (U1 of loop 77), the Rust `BadValue` for directions 0 and 4 (U1 of loop 78, kept).
- The test vectors `fixtures/frame/vectors.txt` and the package sources: no package behavior changes.
- Splitting `handoff.cpp` (631 lines before this task).

## Acceptance Criteria

Loop ACs: `_docs/02_task_plans/ring-and-test-build-fixes/acceptance_criteria.md` AC-1 to AC-7, AC-12 (ring part), AC-13, AC-14.

**AC-1: Out-of-range numbers end every driver**
Given each of the 8 drivers and each of 8 lines (direction 256 and `-1` on a seal line, tag length 256 on a seal line, kind 256 and `clear_len` 65,536 on an open line, `out_len` 65,536 on a seal line, epoch 4,294,967,296 on a mac line, `n` 256 on a verify line)
When the driver reads the line
Then it exits non-zero, prints no result line for it, and its message holds the line number (64 runs, 0 failures)

**AC-2: Top-of-range numbers reach the package unchanged**
Given direction 255 on a seal line, epoch 4,294,967,295 on a mac line, `out_len` 65,535 on a seal line
When each of the 8 drivers reads them
Then it prints `BadValue`, `BadValue` and the sealed body and exits 0 (24 runs); the driver script has 132 checks (was 44)

**AC-3: The new checks are not vacuous**
Given the drivers of HEAD `cb6759b` put back in a scratch copy
When the driver script runs
Then the direction-256 case fails for C#, C++ and Go and the `-1` case fails for Python

**AC-4: The loader keeps rows inside the rule**
Given a `ring-cases.txt` row with direction 256, and one with `out_len` 65,536
When `ring_frame.py` loads the file
Then it exits 1 and names the row (2 cases in `ring-frame.test.sh`)

**AC-5: Rows at the top of the ranges**
Given the 6 new rows
When `ring-frame.sh` runs with all 8 languages
Then it exits 0 and prints `refusals <lang>: 43 rows, 0 mismatched` for each of the 8 (was 38) and `64 pairs, mismatched: 0`

**AC-6: The ranges are written down**
Given `fixtures/frame/README.md`
When a maintainer reads the ring section
Then it names the range of `epoch`, `dir`, `tag_len`, `kind`, `n`, `clear_len`, `out_len` and the digits-only rule

**AC-7: No hidden mismatch**
Given a stand-in reader with 7 mismatched refusal rows, a pair with 6 mismatches, and a reader with 5
When `check` prints its report
Then it prints 5 lines and `... and 2 more`, 5 lines and `... and 1 more`, and 5 lines with no such line; the mismatch totals are unchanged

## Non-Functional Requirements

**Performance**
- The step 11 `ring` stage grows by no more than 20 s over its figure on HEAD at the same load (loop AC-12).

**Compatibility**
- A driver line without `dirs` and `out_len` still means `123` and 300 bytes. All 8 toolchains as in CI: C++ clean under `g++ -std=c++17 -O2 -Wall -Wextra -Werror` in `gcc:16`, Swift built in `swift:6.3.3` with `--static-swift-stdlib`, Go `gofmt` and `go vet` in `golang:1.27`, Rust without warnings.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | `ring-frame.test.sh`: loader on a row with direction 256 and one with `out_len` 65,536 | exit 1, row named |
| AC-7 | `ring-frame.test.sh`: stand-in drivers with 7, 6 and 5 mismatches | `... and 2 more`, `... and 1 more`, no line |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | real drivers built as `ring-frame.sh` builds them | `ring-frame-drivers.test.sh` 8 out-of-range lines x 8 drivers | 64 PASS | Compatibility |
| AC-2 | same | 3 top-of-range lines x 8 drivers | 24 PASS, total 132 | — |
| AC-3 | scratch copy with HEAD `cb6759b` drivers | the driver script | FAIL for C#, C++, Go (direction 256) and Python (`-1`) | — |
| AC-5 | all 8 toolchains | `ring-frame.sh` | `43 rows, 0 mismatched` x 8, `64 pairs, mismatched: 0` | Performance |

## Constraints

- The range rule is the owner's (2026-10-28, "Accept all recommended"): out of range is a malformed line in every driver, not a driver-made `BadValue`.
- `clear_len` takes the range of `out_len` (assumption confirmed by auto-apply in new-task Step 5).
- A CI ring step added or changed goes into `scripts/loop-tests.sh` in the same commit (LESSONS, loop 78).

## Risks & Mitigation

**Risk 1: Eight toolchains in one change**
- *Risk*: a driver edit not built on its CI toolchain breaks the `ring` job (loop 77: six defects on the first push).
- *Mitigation*: run the real ring and the driver script on the Mac and each container check above before the batch commit.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Eight drivers change at once | real ring + driver script + container builds before the commit (LESSONS, loop 77) | open | Medium |
| New checks pass on the first run and prove nothing alone | AC-3: old drivers put back (LESSONS, loop 78) | open | Low |
| Python, TypeScript and Java stop handing a direction above 255 to the package | owner accepted the uniform rule (2026-10-28) | accepted-risk | Low |
