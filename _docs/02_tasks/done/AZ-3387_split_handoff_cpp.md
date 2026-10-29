---
loop: 83
branch: dev
---

# Split the C++ ring driver handoff.cpp

**Task**: AZ-3387_split_handoff_cpp
**Name**: Split the C++ ring driver handoff.cpp under the 500-line cap
**Description**: `.github/workflows/drivers/handoff.cpp` (639 lines) becomes files of at most 500 lines, built into the same driver binary, with no change of behaviour.
**Complexity**: 3 points
**Dependencies**: None
**Component**: Cross-language ring (`.github/workflows/drivers/`, `ring-lib.sh`)
**Tracker**: AZ-3387
**Epic**: none

## Problem

`handoff.cpp` is the one C++ driver of the ring and holds four jobs in 639 lines: the element rows (lines 13-300: `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `roundflags`, `roundwhen` and their `*_ok` checks), the ECC driver (`ecc_*`, 308-406), the frame driver (`frame_*`, 408-586) and `main` (588). The source-length cap is 500 lines (`quality-thresholds.md`). `ring-lib.sh:46` compiles it with six `cpp/src/core/*.cpp` in one command and is the only file that names `handoff.cpp`.

## Outcome

- No `.cpp` file in `.github/workflows/drivers/` over 500 lines.
- The ring behaves exactly as before.

## Scope

### Included
- Split along the file's sections: the rows and `main` stay in `handoff.cpp`; the ECC driver and the frame driver move to their own `.cpp` files; a small header only for what two parts share (`parse_hex`, `print`, the hex helpers); names with internal linkage stay in an anonymous namespace of the file that uses them.
- The compile line of `ring-lib.sh` names the new sources; the `|| return`, the compile-once rule and the `PACKBIN_CPP_HANDOFF` rebuild stay.
- Any script or test that lists the driver sources (a `git grep` of `handoff.cpp` and of the compile line is run before the commit; at HEAD only `ring-lib.sh:46`).

### Excluded
- `cpp/embedded/common/all_kinds.cpp` (560 lines; not picked by the owner).
- Any change to what the driver prints, to its argument grammar or to the other seven drivers.
- Renames, new abstractions, new tests of the driver's internals.

## Acceptance Criteria

**AC-1: Under the cap**
Given the tree after the task
When `wc -l .github/workflows/drivers/*.cpp .github/workflows/drivers/*.hpp` is read
Then every file is at most 500 lines (HEAD: `handoff.cpp` 639, `position.cpp` 35)

**AC-2: Builds clean**
Given the compile line of `ring-lib.sh` (`-std=c++17 -O2 -Wall -Wextra -Werror`)
When the driver is built with `g++` here and with `gcc:16` in docker
Then 0 warnings, 0 errors, and the build is stopped by a failing compile (`|| return`)

**AC-3: Same behaviour**
Given the ring on HEAD (log kept in the scratchpad: `ring-frame: 64 pairs, mismatched: 0`, 45 rows per pair, 58 refusal rows per language) and `language-pair.sh` green
When both run after the split
Then `ring-frame.sh` ends `64 pairs, mismatched: 0` with the same row counts per pair and per language, `language-pair.sh` exits 0, and the C++ driver output for the same input file is byte-identical to the output of the HEAD binary (`cmp` on `frame-batch` and on the ECC and element modes)

**AC-4: Build rules kept**
Given `ring-lib.sh` after the task
When read and run twice
Then the driver is compiled once per run, `PACKBIN_CPP_HANDOFF` set forces a compile on every call, and a compile error makes `run_lang cpp` return non-zero (a copy with one deliberate error shows it)

**AC-5: Wiring checks**
Given `ring-lib.test.sh`, `ring-wiring.test.sh`, `ring-wiring-rows.test.sh`, `ring-frame-drivers.test.sh`
When they run
Then all pass (the rows test names the C++ driver's refusals; they must still be found in the split files)

## Non-Functional Requirements

**Compatibility**
- GCC 16 (CI) and Apple clang, `-Wall -Wextra -Werror`, C++17.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `wc -l` of each driver source | at most 500 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | HEAD log and HEAD binary | `ring-frame.sh`, `language-pair.sh`, `cmp` of driver output | same counts, byte-identical output | none |
| AC-4 | copy of the compile line with a deliberate error | `run_lang cpp` | non-zero, no stale binary run | none |
| AC-5 | the four scripts | run | PASS | none |

## Constraints

- Exclusive paths: `.github/workflows/drivers/handoff*.cpp`, `.github/workflows/drivers/*.hpp` (new), `.github/workflows/ring-lib.sh`. The rows task (AZ-3389) may not edit these.

## Risks & Mitigation

**Risk 1: A scripted check greps the driver for a kind or refusal name** (the rows test names the C++ driver's refusals)
- *Mitigation*: run `ring-wiring-rows.test.sh` and read its C++ lines; a grep over the new files.

**Risk 2: A stale binary stands in for a failed build**
- *Mitigation*: AC-4.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One translation unit becomes several; the compile line must name all | AC-3, AC-4 | open | Medium |
| Output of the C++ driver changes by accident | `cmp` against the HEAD binary | open | Medium |
