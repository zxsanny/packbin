---
loop: 84
branch: dev
---

# Split all_kinds.cpp under the 500-line cap

**Task**: AZ-3391_split_all_kinds_cpp
**Name**: Split cpp/embedded/common/all_kinds.cpp
**Description**: The 560-line file becomes parts of 500 lines or less, built by all 3 consumers, with identical results.
**Complexity**: 3 points
**Dependencies**: None
**Component**: C++ embedded (`cpp/embedded/common/`, `cpp/Makefile`, `cpp/embedded/arm.sh`, `cpp/embedded/esp/main/CMakeLists.txt`)
**Tracker**: AZ-3391
**Epic**: none

## Problem

`all_kinds.cpp` is 560 lines, over the cap (`quality-thresholds.md`). Sections on HEAD: includes and shared helpers (1-110), base row (`mismatched_fields`, ~179-250), plain chain (`chain_*`, 250-316), flag chain (`flag_chain_*`, 317-355), round chain with its own anonymous namespace (356-454), flag-round chain with its own anonymous namespace (455-559). Consumers name the file in 5 places: `cpp/Makefile:16` (`IMAGE_SRCS`, with the header) and `:32`, `cpp/embedded/arm.sh:45` and `:349`, `cpp/embedded/esp/main/CMakeLists.txt:3`. `all_kinds.hpp` declares everything under `namespace all_kinds`.

## Outcome

- No file under `cpp/embedded/common/` over 500 lines.
- Every consumer builds every part; behaviour is byte-identical.

## Scope

### Included
- Split along the file's own sections (the worker picks the cut: e.g. base + plain/flag chains, and the two `times`-round families in a second file); a small internal header only for helpers two parts really share (`set_text`, `same_text`, `differs`).
- `all_kinds.hpp` stays the public header; its declarations do not change.
- The 5 consumer lines updated; `IMAGE_SRCS` lists the new files.
- Baselines recorded on HEAD before editing: `make -C cpp test` pass count; the vectors program's output lines; ARM image size if a stage prints it.

### Excluded
- Any change of a scheme, row, sample value or expected bytes; `ecc_probe.*`, `vectors_main.cpp`.
- A new abstraction or macro; renaming `all_kinds` symbols.

## Acceptance Criteria

**AC-1: Under the cap**
Given the tree after the task
When `wc -l cpp/embedded/common/*.cpp` runs
Then every file is 500 lines or less (HEAD: `all_kinds.cpp` 560)

**AC-2: Host build and tests**
Given gcc:16 with `-Wall -Wextra -Werror`
When `make -C cpp test` runs
Then it ends with the pass count of HEAD and 0 warnings

**AC-3: Every consumer lists every part**
Given the 3 consumers
When each is read (and `git grep -n 'all_kinds'` over `cpp/` and `.github/`)
Then none builds the old file alone; `IMAGE_SRCS` names all parts

**AC-4: Results identical**
Given the vectors program built from HEAD and from the task
When both run
Then the printed lines are identical (pack bytes, unpack, `*_failures` of the base row and the 4 families)

**AC-5: Embedded stages**
Given the stages this host can run (`cpp/embedded/arm.sh` host-runnable parts, big-endian run)
When they run
Then each ends as on HEAD; a stage the host cannot run is reported NOT RUN (never a pass); the ESP-IDF CMake source list is checked by reading it against the parts

## Non-Functional Requirements

**Compatibility**
- C++17, no exceptions/RTTI as the embedded build sets; no new heap use; image size reported before/after where a stage prints it.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `wc -l` | all <= 500 |
| AC-2 | `make -C cpp test` | HEAD's pass count |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | vectors program | HEAD vs new output | identical | none |
| AC-5 | arm.sh / big-endian stage | run what the host can | as HEAD, rest NOT RUN | image size |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A consumer missed: links on one host, fails on another | AC-3 reads all 3; AC-5 runs what it can | open | High |
| Symbols move between translation units (image size, ODR of the anonymous namespaces) | AC-4; sizes reported | open | Medium |
