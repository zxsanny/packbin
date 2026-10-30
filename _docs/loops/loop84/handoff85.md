# Handoff to loop 85

From the loop 84 record (`record84.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 84

AZ-3390 to AZ-3393 (11 points, In Testing):
- The scaffold wiring check requires the steps of `yaml_get.test.sh` and `workflow_yaml.test.sh` (`SCAFFOLD_SCRIPTS` 3 -> 5, 2 mutants; `ring-wiring.test.sh` 38 -> 42 mutants).
- `all_kinds.cpp` (560 lines) is `all_kinds.cpp` 314 + `all_kinds_rounds.cpp` 246 + `all_kinds_internal.hpp`; the Cortex-M33F image is 25,760 B and `m33f_flash_pin` is 25,760 (owner, 2026-10-30; line in `AGENT_GOTCHAS.md`).
- `RING_PYTHON` is the one Python version of `test.yml` (workflow env); the wiring check rejects a literal `python-version`.
- `ring_frame.py` reads `RING_FRAME_SHOWN` (default 5); the `id-padded` test sets it, so new rows ahead of its needle no longer break it. No include was unused.

## First actions of loop 85

0. Read the CI of the loop 84 push (`dev` and `main`; see `record84.md` `ci:`), the first run of `embedded-esp-core` and `embedded-esp-packages` on `all_kinds_rounds.cpp` included. Put its result in the first commit of loop 85; do not push a record-only commit.
1. `uptime`, `df -h /tmp` (the publish gate needs free space; delete any scratchpad tree copies first) and `ps -Ao pcpu,command --sort=-pcpu | head`. A total run is not a result above load 60 from a foreign job.
2. The JDK is a user-directory tarball (`~/.local/share/packbin-jdk26/bin`), not on PATH by default: the ring stage needs it on PATH. `LOOP_TESTS_PYTHON` must point to a Python 3.10+ on this Linux host (the script defaults to a Homebrew path).
3. `docker rmi packbin-embedded:w2` frees 4.9 GB when the owner agrees (a worker built it; `loop-tests.sh` builds its own image).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step.
- Multi-part MAC rows in the ring (G8m of loop 77) were owner-declined then; they need an opt-in like U1 had.
- New: with the hopper holding only file-size and wiring hygiene, the next loops either take an owner decision from the list above or run out of ready work (retro of loop 84, action 3).

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76 and loop 84)

- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Refresh the stage stamps on the owner's Mac (one clean run; this Linux clone has none).
- Low review items of loop 84: compare a job-level `RING_PYTHON` override of a non-ring job with the compose image; reject a non-numeric `RING_FRAME_SHOWN` with a message.
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L84-1**: `m33f_flash_pin` has zero margin again (25,760 B measured = pin); the next edit that adds a byte to the M33F image fails the row by its own bytes.
- **L84-2**: the ESP-IDF jobs have not run on the new source list; CI is their first run.
- **L83-1**: the new ring rows prove the order in 6 of 8 languages; Rust and C++ print `BadValue` by construction (said in `fixtures/frame/README.md`).
- **L82-2, L82-3, L81-2, L80-1, L80-2, L78-2, L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff83.md`, `handoff82.md`, `handoff81.md`, `handoff80.md`, `handoff76.md` and `handoff75.md`.
