---
loop: 84
branch: dev
---

# CI wiring, all_kinds.cpp and review cleanups (loop 84)

Source: `_docs/loops/loop83/handoff84.md` (§Candidates) and the owner's pick of all four listed candidates on 2026-10-30 (hopper empty). Every figure below was read on HEAD a925aa7 in this loop (LESSONS loop 76: probe each candidate on HEAD first).

## Problem

Four small defects in the CI wiring checks and the C++ sources:

1. **The scaffold wiring check does not require two CI steps.** `SCAFFOLD_SCRIPTS` in `.github/workflows/ring-wiring-check.py:27` names 3 scripts the `scaffold` job of `test.yml` must run (`cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, `ring-wiring-rows.test.sh`). The steps "CI YAML reader" (`bash scripts/ci/yaml_get.test.sh`, test.yml:368) and "CI workflow helpers" (`bash scripts/ci/workflow_yaml.test.sh`, test.yml:370) are not in it, so deleting either leaves every wiring test green. `ring-wiring.test.sh:122-124` has one mutant per named step.
2. **`cpp/embedded/common/all_kinds.cpp` is 560 lines**, over the 500-line cap (`quality-thresholds.md`). It holds the base row (lines 1-250), and three chain families each with its own anonymous namespace: the plain chain (276-355), the round chain (356-454) and the flag-round chain (455-559). Consumers compile it by name in 3 places: `cpp/Makefile:16,32`, `cpp/embedded/arm.sh:45,349`, `cpp/embedded/esp/main/CMakeLists.txt:3`.
3. **Review cleanups of loop 83** (batch review PASS_WITH_WARNINGS, `record83.md`). Probed on HEAD:
   - the include lists of `handoff_ecc.cpp` (5 headers) and `handoff_frame.cpp` (8) were copied from the original `handoff.cpp`; some headers may not be used by their part;
   - the needle of `id-padded` (`ring-frame.test.sh:184`, "go: R.open.id7 open gave TagMismatch") sits in a list that `scripts/frame/ring_frame.py:38` (`SHOWN = 5`) caps at 5 lines per reader, so a row sorted ahead of it breaks the test;
   - **not a defect on HEAD:** `kMax` of `handoff_common.hpp` is read by two parts (`handoff.cpp` 178/252/263/277, `handoff_ecc.cpp` 52/67), not one; `frame_hex` is a wrapper of `hex_of` on purpose (`-` is the wire word for an empty field, `hex_of` prints nothing). Both stay as they are and the spec says why.
4. **The Python version is spelled in 3 places of `test.yml`**: `RING_PYTHON: "3.14"` (job env of `ring`, line 23) and two `python-version: "3.14"` literals (jobs `publish-gate-rest` 251 and `scaffold` 336), plus the suite image `python:3.14` of `docker-compose.test.yml:33`, which `ring-wiring-check.py` compares with `RING_PYTHON` (`SUITES`, line 25). One bump needs 4 edits; forgetting one of the literals is not caught.

## Change location

No UI. As the owner named them in the handoff:
- "Make the scaffold wiring check require the steps of `yaml_get.test.sh` and `workflow_yaml.test.sh` (a mutant per step in `ring-wiring.test.sh`)" - `.github/workflows/ring-wiring-check.py`, `ring-wiring.test.sh`, `test.yml`.
- "`cpp/embedded/common/all_kinds.cpp` is 560 lines, over the 500 cap" - that file and its three consumers above.
- "The review cleanups of loop 83 (`frame_hex` over `hex_of`, copied include lists, the `id-padded` needle and the 5-line cap)" - `.github/workflows/drivers/handoff*.cpp`, `ring-frame.test.sh`.
- "Folding the Python version of the two `setup-python` steps and `RING_PYTHON` into one place" - `.github/workflows/test.yml`.

## Points the design must settle

- **Write sets.** T1 (scaffold steps) and T4 (Python version) both edit `ring-wiring-check.py` and `ring-wiring.test.sh`: one worker, T1 then T4. T2 owns `cpp/` (Makefile, `embedded/`), T3 owns `.github/workflows/drivers/handoff*.cpp`, `ring-frame.test.sh` and `scripts/frame/ring_frame.py`. `test.yml` belongs to the T1/T4 worker.
- **T2 seams** follow the file's own sections (base row; one file per chain family when a part exceeds the cap on its own); a shared header only for what two parts really share (`set_text`, `same_text`, `differs`). No new abstraction. Every consumer lists the new sources; none is left naming only `all_kinds.cpp`.
- **T4 shape.** The version lives in one workflow-level `env` entry; the two literals read it; the wiring check keeps comparing it with the compose image tag (it must read workflow-level env as it reads job env today).
- **A cleanup that is not a defect on HEAD is not applied.** The spec records the probe, as above for `kMax` and `frame_hex`.

## Out of scope

Multi-part MAC rows; the AVR `chacha20_xor` check; stage stamps on the Mac; every "owner input needed" line of the handoff; `publish.yml` (no `setup-python` step); the Go window floor, `item` pointer, `session_core` clippy, `nostd` ring driver, 128 KiB image, cycle timing.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The scaffold list is the net under the CI helper tests; a new entry can be mis-spelled and then match nothing | each new entry gets a mutant that deletes its step; the mutant must be rejected for that step's message | open | High |
| `all_kinds.cpp` is compiled by the ARM firmware, the ESP-IDF build and the host test; a source missing from one consumer links on one host and fails on another | all 3 consumers updated in the task; the stages this host can run are run, the others are said to be NOT RUN (never a pass) | open | High |
| The firmware image changes shape (symbols move between translation units) | the pack/unpack results of every row stay byte-identical; image size is reported, not pinned, unless a stage pins it | open | Medium |
| Pruned includes break a build that compiles by luck (a header pulled in by another) | each removed header is justified by "no symbol of it used" in the part; `-Wall -Wextra -Werror` on gcc:16 and the ring build pass | open | Medium |
| Moving `RING_PYTHON` to workflow level changes what the checker reads | the checker reads workflow env; a mutant that restores a literal `3.14` in `python-version` is rejected | open | Medium |
| Only the cap of the mismatch list, not its output, changes for T3 | `ring-frame.sh` output unchanged | accepted-risk | Low |
